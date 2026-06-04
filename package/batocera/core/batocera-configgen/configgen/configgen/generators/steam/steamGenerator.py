from __future__ import annotations

import shlex
import os
import re
from pathlib import Path
from typing import TYPE_CHECKING

from ... import Command
from ...utils import lsfg
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext

_STEAM_FRONTEND_LAUNCHERS = {
    "Steam.steam",
    "SteamOS Mode.steam",
    "Steam GamepadUI.steam",
    "Steam GamepadUI No Gamescope.steam",
    "Steam Desktop.steam",
}
_STEAM_APP_DIRS = (
    Path("/userdata/system/steam/steamapps"),
    Path("/userdata/system/.steam/steam/steamapps"),
    Path("/userdata/system/.local/share/Steam/steamapps"),
)
_STEAM_SKIP_EXE_NAMES = {
    "crashhandler.exe",
    "crashpad_handler.exe",
    "crashpad_database_util.exe",
    "crashpad_http_upload.exe",
    "crashreportclient.exe",
    "crashreporter.exe",
    "dxsetup.exe",
    "easyanticheat_eos_setup.exe",
    "forzaprotocolselector.exe",
    "forzawebhelper.exe",
    "hardwarereporter.exe",
    "machineidentifier.exe",
    "msedgewebview2.exe",
    "notification_helper.exe",
    "oalinst.exe",
    "workshopuploader.exe",
    "unitycrashhandler32.exe",
    "unitycrashhandler64.exe",
    "unins000.exe",
    "uninstall.exe",
    "vc_redist.x64.exe",
    "vc_redist.x86.exe",
    "vcredist_x64.exe",
    "vcredist_x86.exe",
    "watchdog.exe",
    "watchdog64.exe",
}
_STEAM_SKIP_EXE_DIRS = {
    "_commonredist",
    "directx",
    "dotnet",
    "installer",
    "installscript",
    "redist",
    "redistributable",
    "redistributables",
    "support",
    "tools",
    "vcredist",
}
_STEAM_SKIP_APP_NAME_TOKENS = (
    "proton",
    "steam linux runtime",
    "steamworks common redistributables",
)
_STEAM_SKIP_APP_INSTALLDIR_TOKENS = (
    "proton",
    "steamlinuxruntime",
    "steamworks shared",
)


def _parse_steam_rom_entry(content: str) -> dict[str, str]:
    entry: dict[str, str] = {}
    raw = content.strip()
    if not raw:
        return entry

    # Backward compatibility: plain numeric appid in file.
    if "=" not in raw and raw.isdigit():
        entry["appid"] = raw
        return entry
    if "=" not in raw and raw.startswith("steam://rungameid/"):
        appid = raw.removeprefix("steam://rungameid/").strip()
        if appid.isdigit():
            entry["appid"] = appid
            return entry

    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        if line.startswith("steam://rungameid/"):
            appid = line.removeprefix("steam://rungameid/").strip()
            if appid.isdigit():
                entry["appid"] = appid
            continue

        if line.lower().startswith("appid:"):
            appid = line.split(":", 1)[1].strip()
            if appid.isdigit():
                entry["appid"] = appid
            continue

        if "=" not in line:
            parts = line.split()
            if len(parts) == 2 and parts[0].lower() == "appid" and parts[1].isdigit():
                entry["appid"] = parts[1]
            continue
        key, value = line.split("=", 1)
        key = key.strip().lower()
        value = value.strip()
        if key and value:
            entry[key] = value
    return entry


def _vdf_get(content: str, key: str) -> str | None:
    match = re.search(rf'"{re.escape(key)}"\s*"([^"]*)"', content, flags=re.IGNORECASE)
    if match:
        return match.group(1)
    return None


def _steamapps_dirs() -> list[Path]:
    dirs: list[Path] = []
    for steamapps in _STEAM_APP_DIRS:
        if steamapps.is_dir() and steamapps not in dirs:
            dirs.append(steamapps)

        libraryfolders = steamapps / "libraryfolders.vdf"
        if not libraryfolders.is_file():
            continue
        try:
            content = libraryfolders.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue

        for raw_path in re.findall(r'"path"\s*"([^"]+)"', content, flags=re.IGNORECASE):
            library_path = Path(raw_path.replace("\\\\", "\\"))
            library_steamapps = library_path / "steamapps"
            if library_steamapps.is_dir() and library_steamapps not in dirs:
                dirs.append(library_steamapps)

    return dirs


def _steam_app_dirs(appid: str | None = None) -> list[Path]:
    app_dirs: list[Path] = []
    for steamapps in _steamapps_dirs():
        for manifest in steamapps.glob("appmanifest_*.acf"):
            try:
                content = manifest.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue

            manifest_appid = _vdf_get(content, "appid")
            if appid is not None and manifest_appid != appid:
                continue

            name = (_vdf_get(content, "name") or "").lower()
            installdir = _vdf_get(content, "installdir")
            if not installdir:
                continue
            installdir_lower = installdir.lower()
            if appid is None and (
                any(token in name for token in _STEAM_SKIP_APP_NAME_TOKENS)
                or any(token in installdir_lower for token in _STEAM_SKIP_APP_INSTALLDIR_TOKENS)
            ):
                continue

            app_dir = steamapps / "common" / installdir
            if app_dir.is_dir() and app_dir not in app_dirs:
                app_dirs.append(app_dir)

    return app_dirs


def _is_probable_game_exe(path: Path) -> bool:
    name = path.name.lower()
    if not name.endswith(".exe") or name in _STEAM_SKIP_EXE_NAMES:
        return False

    lower_parts = {part.lower() for part in path.parts}
    return not bool(lower_parts & _STEAM_SKIP_EXE_DIRS)


def _steam_game_exes(appid: str | None = None) -> list[str]:
    exes: list[str] = []
    for app_dir in _steam_app_dirs(appid):
        for root, dirs, files in os.walk(app_dir):
            dirs[:] = [
                directory for directory in dirs
                if directory.lower() not in _STEAM_SKIP_EXE_DIRS and not directory.startswith(".")
            ]
            for filename in files:
                exe = Path(root) / filename
                if _is_probable_game_exe(exe) and exe.name not in exes:
                    exes.append(exe.name)

    return exes


def _entry_lsfg_exes(entry: dict[str, str]) -> list[str]:
    raw = entry.get("lsfg_process") or entry.get("lsfg_processes") or entry.get("lsfg_exe") or entry.get("lsfg_exes") or ""
    exes: list[str] = []
    for value in re.split(r"[,;]", raw):
        exe = Path(value.strip()).name
        if exe and exe not in exes:
            exes.append(exe)
    return exes


def _normalize_bool_override(value: str | None) -> str | None:
    if value is None:
        return None

    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return "1"
    if normalized in {"0", "false", "no", "off"}:
        return "0"
    return None


def _normalize_steam_user(value: str | None) -> str:
    if value is None:
        return "auto"

    normalized = value.strip()
    if not normalized:
        return "auto"

    lowered = normalized.lower()
    if lowered in {"auto", "default", "current"}:
        return "auto"
    if lowered in {"prompt", "ask", "ask-every-time", "chooser", "choose"}:
        return "prompt"

    return normalized


def _normalize_steam_mode(value: str | None) -> str | None:
    if value is None:
        return None

    normalized = value.strip().lower()
    if not normalized:
        return None

    if normalized in {"steamos", "gamescope", "gamemode"}:
        return "steamos"
    if normalized in {"gamepadui", "gamepad-ui"}:
        return "gamepadui"
    if normalized in {"desktop", "plasma"}:
        return "desktop"

    return None


class SteamGenerator(Generator):

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        def _select_or_custom(key: str, custom_key: str) -> str:
            value = system.config.get_str(key, "").strip()
            if value == "custom":
                return system.config.get_str(custom_key, "").strip()
            return value

        def _positive_int(value: str) -> int | None:
            if not value or not value.isdigit():
                return None
            parsed = int(value)
            if parsed <= 0:
                return None
            return parsed

        basename = rom.name
        entry: dict[str, str] = {}
        gameId = None
        command_override = None
        mode_override = None
        extra_args_override = None
        gamepadui_override = None
        gamescope_override = None
        steam_user_override = None
        visible_update_preflight_override = None
        update_preflight_no_update_secs_override = None
        if basename != "Steam.steam":
            # read the id inside the file
            with rom.open() as f:
                entry = _parse_steam_rom_entry(f.read())
            gameId = entry.get("appid") or entry.get("gameid")
            mode_override = entry.get("mode")
            command_override = entry.get("command") or entry.get("exec")
            extra_args_override = entry.get("extra_args") or entry.get("args")
            gamepadui_override = entry.get("gamepadui")
            gamescope_override = entry.get("gamescope")
            steam_user_override = entry.get("steam_user") or entry.get("user") or entry.get("account")
            visible_update_preflight_override = entry.get("visible_update_preflight") or entry.get("update_preflight")
            update_preflight_no_update_secs_override = entry.get("update_preflight_no_update_secs") or entry.get("preflight_no_update_secs")

        direct_session_path = Path("/usr/bin/steam-direct-session.sh")

        if command_override:
            try:
                commandArray = shlex.split(command_override)
            except ValueError:
                commandArray = [command_override]
            if not commandArray:
                commandArray = ["batocera-steam"]
        elif gameId is None:
            commandArray = ["batocera-steam"]
        else:
            commandArray = ["batocera-steam", gameId]

        # Fix for Xbox Bluetooth controllers not working with Steam (issue #12731)
        # xpadneo fixes mappings at evdev level, but Steam reads raw HIDAPI data
        normalized_mode_override = _normalize_steam_mode(mode_override)
        normalized_core = _normalize_steam_mode(system.config.core)
        legacy_mode = _normalize_steam_mode(system.config.get_str("steam_session_mode", "steamos")) or "steamos"
        mode = normalized_mode_override or normalized_core or legacy_mode

        nested_refresh = system.config.get_int("gamescope_nested_refresh", -1)
        nested_unfocused_refresh_raw = _select_or_custom("gamescope_nested_unfocused_refresh", "gamescope_nested_unfocused_refresh_custom")
        nested_unfocused_refresh = _positive_int(nested_unfocused_refresh_raw)
        output_resolution = _select_or_custom("gamescope_output_resolution", "gamescope_output_resolution_custom")
        nested_resolution = _select_or_custom("gamescope_nested_resolution", "gamescope_nested_resolution_custom")
        xwayland_count_raw = _select_or_custom("gamescope_xwayland_count", "gamescope_xwayland_count_custom")
        xwayland_count = _positive_int(xwayland_count_raw)
        sharpness = _select_or_custom("gamescope_sharpness", "gamescope_sharpness_custom")
        framerate_limit_raw = _select_or_custom("gamescope_framerate_limit", "gamescope_framerate_limit_custom")
        framerate_limit = _positive_int(framerate_limit_raw)
        backend = system.config.get_str("gamescope_backend", "").strip()
        if backend not in {"auto", "drm", "wayland", "sdl", "headless"}:
            backend = ""
        steam_user = _normalize_steam_user(system.config.get_str("steam_user", "auto"))

        # Legacy configs used the steam_session_mode/gamescope cfeature pair. The new
        # Steam setup maps explicit Steam cores directly to one of three launch modes.
        steam_gamepadui = system.config.get_bool("steam_gamepadui", True, return_values=("1", "0"))
        use_gamescope = system.config.get_bool("gamescope", True)
        if normalized_mode_override is not None or normalized_core is not None:
            if mode == "desktop":
                steam_gamepadui = "0"
                use_gamescope = False
            elif mode == "gamepadui":
                steam_gamepadui = "1"
                use_gamescope = False
            else:
                steam_gamepadui = "1"
                use_gamescope = True

        normalized_gamepadui = _normalize_bool_override(gamepadui_override)
        if normalized_gamepadui is not None:
            steam_gamepadui = normalized_gamepadui

        normalized_gamescope = _normalize_bool_override(gamescope_override)
        if normalized_gamescope is not None and mode != "desktop":
            use_gamescope = normalized_gamescope == "1"

        if mode == "desktop":
            steam_gamepadui = "0"
            use_gamescope = False

        direct_session_requested = mode != "desktop" and use_gamescope and direct_session_path.exists()
        if direct_session_requested:
            commandArray = [str(direct_session_path)]
            if gameId is not None:
                commandArray.append(gameId)

        gamescope_mangoapp = system.config.get_bool("gamescope_mangoapp", True, return_values=("1", "0"))
        mangoapp_color_workaround = system.config.get_bool(
            "gamescope_mangoapp_color_workaround",
            False,
            return_values=("1", "0"),
        )

        env = {
            "SDL_JOYSTICK_HIDAPI_XBOX": "0",
            "BATOCERA_STEAM_MODE": mode,
            "BATOCERA_STEAM_USE_GAMESCOPE": "1" if use_gamescope else "0",
            "BATOCERA_STEAM_GS_OUTPUT_RES": output_resolution,
            "BATOCERA_STEAM_GS_NESTED_RES": nested_resolution,
            "BATOCERA_STEAM_GS_BACKEND": backend,
            "BATOCERA_STEAM_GS_PREFER_VK_DEVICE": system.config.get_str("gamescope_prefer_vk_device", "").strip(),
            "BATOCERA_STEAM_GS_SCALER": system.config.get_str("gamescope_scaler", ""),
            "BATOCERA_STEAM_GS_FILTER": system.config.get_str("gamescope_filter", ""),
            "BATOCERA_STEAM_GS_SHARPNESS": sharpness,
            "BATOCERA_STEAM_GS_HDR": system.config.get_bool("gamescope_hdr", return_values=("1", "0")),
            "BATOCERA_STEAM_GS_ADAPTIVE_SYNC": system.config.get_bool("gamescope_adaptive_sync", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_DISABLE_DAMAGE_TRACKING": system.config.get_bool("gamescope_disable_damage_tracking", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_DISABLE_HW_COMPOSITION": system.config.get_bool("gamescope_disable_hw_composition", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_FORCE_COMPOSITION_PIPELINE": system.config.get_bool("gamescope_force_composition_pipeline", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_MANGOAPP": gamescope_mangoapp,
            "BATOCERA_STEAM_MANGOAPP_COLOR_WORKAROUND": mangoapp_color_workaround,
            "BATOCERA_STEAM_GS_FORCE_WINDOWS_FULLSCREEN": system.config.get_bool("gamescope_force_windows_fullscreen", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_IMMEDIATE_FLIPS": system.config.get_bool("gamescope_immediate_flips", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_DISABLE_COLOR_MANAGEMENT": system.config.get_bool("gamescope_disable_color_management", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_DISABLE_XRES": system.config.get_bool("gamescope_disable_xres", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_STATS_PATH": system.config.get_str("gamescope_stats_path", "").strip(),
            "BATOCERA_STEAM_GAMEPADUI": steam_gamepadui,
            "BATOCERA_STEAM_EXTRA_ARGS": system.config.get_str("steam_extra_args", ""),
        }
        if direct_session_requested:
            env["BATOCERA_STEAM_DIRECT_SESSION"] = "1"
            env["BATOCERA_STEAM_USE_GAMESCOPE"] = "1"
        normalized_visible_preflight = _normalize_bool_override(visible_update_preflight_override)
        if normalized_visible_preflight is not None:
            env["BATOCERA_STEAM_VISIBLE_UPDATE_PREFLIGHT"] = normalized_visible_preflight
        preflight_no_update_secs = _positive_int(update_preflight_no_update_secs_override or "")
        if preflight_no_update_secs is not None:
            env["BATOCERA_STEAM_PREFLIGHT_NO_UPDATE_SECS"] = str(preflight_no_update_secs)
        steam_user = _normalize_steam_user(steam_user_override) if steam_user_override is not None else steam_user
        if steam_user != "auto":
            env["BATOCERA_STEAM_USER"] = steam_user
        if extra_args_override:
            env["BATOCERA_STEAM_EXTRA_ARGS"] = extra_args_override
        if nested_refresh > 0:
            env["BATOCERA_STEAM_GS_NESTED_REFRESH"] = str(nested_refresh)
        if nested_unfocused_refresh is not None:
            env["BATOCERA_STEAM_GS_NESTED_UNFOCUSED_REFRESH"] = str(nested_unfocused_refresh)
        if xwayland_count is not None:
            env["BATOCERA_STEAM_GS_XWAYLAND_COUNT"] = str(xwayland_count)
        if framerate_limit is not None:
            env["BATOCERA_STEAM_GS_FRAMERATE_LIMIT"] = str(framerate_limit)
        if gameResolution and "width" in gameResolution and "height" in gameResolution:
            env["BATOCERA_STEAM_GS_DEFAULT_RES"] = f"{gameResolution['width']}x{gameResolution['height']}"

        lsfg_exes = _entry_lsfg_exes(entry)
        for exe in _steam_game_exes(gameId if basename not in _STEAM_FRONTEND_LAUNCHERS else None):
            if exe not in lsfg_exes:
                lsfg_exes.append(exe)
        if lsfg_exes:
            lsfg.apply_lsfg_vk(system, env, use_wine_layer=True, process_names=lsfg_exes, config_name="steam")
        else:
            lsfg.apply_lsfg_vk(system, env, use_wine_layer=True, process_name="steam")

        return Command.Command(array=commandArray, env=env)

    def getMouseMode(self, config, rom):
        return True

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "steam",
            "keys": { "exit": ["KEY_LEFTALT", "KEY_F4"] }
        }
