from __future__ import annotations

import filecmp
import json
import os
import shutil
import stat
import subprocess
from os import environ
from typing import TYPE_CHECKING, Any, Final

try:
    import evdev
except Exception:
    evdev = None

from ... import Command
from ...batoceraPaths import BIOS, CACHE, CONFIGS, ROMS, SAVES, configure_emulator, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ...utils import lsfg
from ...utils.motion import get_dsu_server
from ..Generator import Generator

if TYPE_CHECKING:
    from pathlib import Path

    from ...types import HotkeysContext

ryujinxConf: Final = CONFIGS / "Ryujinx"
ryujinxConfFile: Final = ryujinxConf / "Config.json"
switchBios: Final = BIOS / "switch"
switchKeysDir: Final = switchBios / "keys"
switchNandDir: Final = switchBios / "nand"
switchFirmwareDir: Final = switchBios / "firmware"
ryujinxKeys: Final = switchBios / "prod.keys"
ryujinxExec: Final = ryujinxConf / "ryujinx"

# UCLAMP values (out of 1024)
# 819 = ~80% utilization floor, forces scheduler to use big cores
UCLAMP_MIN = 819
UCLAMP_MAX = 1024


def _choice(value: Any, valid_values: set[str], default: str) -> str:
    string_value = str(value)
    return string_value if string_value in valid_values else default


def _mapped_int(value: Any, aliases: dict[str, int], default: int) -> int:
    string_value = str(value)
    return aliases.get(string_value, aliases.get(string_value.lower(), default))


def _bool_or_default(value: Any, default: bool) -> bool:
    if value in (None, "", "auto", "Auto"):
        return default
    if isinstance(value, str):
        return value.lower() in {"1", "true", "on", "enabled"}
    return bool(value)


def _backend_threading(value: Any) -> str:
    string_value = str(value)
    if string_value in {"true", "1"}:
        return "Auto"
    if string_value in {"false", "0"}:
        return "Off"
    return _choice(string_value, {"Auto", "On", "Off"}, "Auto")


def _graphics_backend(value: Any) -> str:
    aliases = {
        "0": "OpenGl",
        "OpenGL": "OpenGl",
        "1": "Vulkan",
    }
    string_value = str(value)
    return aliases.get(string_value, _choice(string_value, {"OpenGl", "Vulkan"}, "Vulkan"))


def _hide_cursor_mode(value: Any) -> int:
    return _mapped_int(
        value,
        {
            "Never": 0,
            "never": 0,
            "0": 0,
            "OnIdle": 1,
            "onidle": 1,
            "1": 1,
            "Always": 2,
            "always": 2,
            "2": 2,
        },
        1,
    )


def _vsync_mode(value: Any) -> int:
    return _mapped_int(
        value,
        {
            "Switch": 0,
            "switch": 0,
            "true": 0,
            "on": 0,
            "Unbounded": 1,
            "unbounded": 1,
            "0": 1,
            "false": 1,
            "off": 1,
            "1": 0,
            "Custom": 2,
            "custom": 2,
            "2": 2,
        },
        1,
    )


def _dram_size(value: Any) -> int:
    return _mapped_int(
        value,
        {
            "MemoryConfiguration4GiB": 0,
            "memoryconfiguration4gib": 0,
            "0": 0,
            "MemoryConfiguration6GiB": 1,
            "memoryconfiguration6gib": 1,
            "1": 1,
            "MemoryConfiguration8GiB": 2,
            "memoryconfiguration8gib": 2,
            "2": 2,
            "MemoryConfiguration12GiB": 3,
            "memoryconfiguration12gib": 3,
            "3": 3,
        },
        0,
    )


def _set_resolution_scale(conf: dict[str, Any], value: Any) -> None:
    try:
        scale = float(value)
    except (TypeError, ValueError):
        scale = 1.0

    if scale.is_integer() and 1 <= int(scale) <= 4:
        conf["res_scale"] = int(scale)
        conf["res_scale_custom"] = 1.0
    else:
        conf["res_scale"] = -1
        conf["res_scale_custom"] = scale


def _percent_to_unit(value: int, default: int = 100) -> float:
    if value < 0 or value > 100:
        value = default
    return value / 100


ryujinxCtrl: dict[str, Any] = {
        "left_joycon_stick": {
        "joystick": "Left",
        "invert_stick_x": False,
        "invert_stick_y": False,
        "rotate90_cw": False,
        "stick_button": "LeftStick"
      },
      "right_joycon_stick": {
        "joystick": "Right",
        "invert_stick_x": False,
        "invert_stick_y": False,
        "rotate90_cw": False,
        "stick_button": "RightStick"
      },
      "deadzone_left": 0,
      "deadzone_right": 0,
      "range_left": 1,
      "range_right": 1,
      "trigger_threshold": 0,
      "motion": {
        "motion_backend": "GamepadDriver",
        "sensitivity": 100,
        "gyro_deadzone": 1,
        "enable_motion": True
      },
      "rumble": {
        "strong_rumble": 8,
        "weak_rumble": 2,
        "enable_rumble": True
      },
      "left_joycon": {
        "button_minus": "Back",
        "button_l": "LeftShoulder",
        "button_zl": "LeftTrigger",
        "button_sl": "Unbound",
        "button_sr": "Unbound",
        "dpad_up": "DpadUp",
        "dpad_down": "DpadDown",
        "dpad_left": "DpadLeft",
        "dpad_right": "DpadRight"
      },
      "right_joycon": {
        "button_plus": "Start",
        "button_r": "RightShoulder",
        "button_zr": "RightTrigger",
        "button_sl": "Unbound",
        "button_sr": "Unbound",
        "button_x": "Y",
        "button_b": "A",
        "button_y": "X",
        "button_a": "B"
    },
    "version": 1,
    "backend": "GamepadSDL2",
}

class RyujinxGenerator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "ryujinx",
            "keys": {
                "exit": "batocera-es-swissknife --emukill 0.5",
                "menu": "KEY_F4",
                "pause": "KEY_F5",
                "screenshot": "KEY_F8",
                "fastforward": "KEY_F6",
                "volumemute": "KEY_F2",
            }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        mkdir_if_not_exists(ryujinxConf / "system")
        mkdir_if_not_exists(switchBios)
        mkdir_if_not_exists(switchKeysDir)
        stale_prod_key = ryujinxConf / "system" / "prod.key"
        if stale_prod_key.is_symlink():
            stale_prod_key.unlink(missing_ok=True)

        # Copy file & make executable (workaround)
        files_to_copy = [
            ("/usr/ryujinx/Ryujinx", ryujinxExec, 0o0775),
            ("/usr/ryujinx/libSkiaSharp.so", ryujinxConf / "libSkiaSharp.so", 0o0644),
            ("/usr/ryujinx/libHarfBuzzSharp.so", ryujinxConf / "libHarfBuzzSharp.so", 0o0644)
        ]

        for src, dest, mode in files_to_copy:
            if not dest.exists() or not filecmp.cmp(src, dest):
                shutil.copyfile(src, dest)
                dest.chmod(mode)

        # Prefer shared Switch BIOS paths for keys/NAND and link into Ryujinx layout.
        _link_dir_into_expected(switchNandDir, ryujinxConf / "bis")
        _bootstrap_firmware_registered_from_flat_nand(switchNandDir, ryujinxConf / "bis")
        _bootstrap_firmware_registered_from_firmware_dir(ryujinxConf / "bis")
        prod_key_source = _pick_existing_path(
            switchKeysDir / "prod.keys",
            switchBios / "prod.keys",
        )
        title_key_source = _pick_existing_path(
            switchKeysDir / "title.keys",
            switchKeysDir / "title.keys_autogenerated",
            switchBios / "title.keys",
            switchBios / "title.keys_autogenerated",
        )
        if prod_key_source is not None:
            _copy_key_file_into_expected(prod_key_source, ryujinxConf / "system" / "prod.keys")
        if title_key_source is not None:
            _copy_key_file_into_expected(title_key_source, ryujinxConf / "system" / "title.keys")

        # Backward compatibility with legacy /userdata/bios/switch/prod.keys
        if not (ryujinxConf / "system" / "prod.keys").exists() and ryujinxKeys.exists():
            shutil.copyfile(ryujinxKeys, ryujinxConf / "system" / "prod.keys")

        # [Configuration]
        mkdir_if_not_exists(ryujinxConfFile.parent)
        try:
            conf = json.load(ryujinxConfFile.open("r"))
        except Exception:
            conf = {}

        # Set defaults
        conf.pop("hide_cursor_on_idle", None)
        conf["enable_discord_integration"] = False
        conf["check_updates_on_start"] = False
        conf["show_confirm_exit"] = False
        conf["skip_user_profiles"] = system.config.get_bool("ryujinx_skip_user_profiles", True)
        conf.pop("skip_videos", None)
        conf["hide_cursor"] = _hide_cursor_mode(system.config.get("ryujinx_hide_cursor", "OnIdle"))
        conf["game_dirs"] = [str(ROMS / "switch")]
        conf["start_fullscreen"] = True
        conf["show_title_bar"] = system.config.get_bool("ryujinx_show_title_bar", False)
        conf["remember_window_state"] = False
        conf["use_input_global_config"] = False
        conf["start_no_ui"] = _bool_or_default(system.config.get("ryujinx_no_ui", ""), not configure_emulator(rom))
        conf["focus_lost_action_type"] = _choice(
            system.config.get("ryujinx_focus_lost", "DoNothing"),
            {"DoNothing", "BlockInput", "MuteAudio", "BlockInputAndMuteAudio", "PauseEmulation"},
            "DoNothing",
        )
        conf["audio_volume"] = _percent_to_unit(system.config.get_int("ryujinx_audio_volume", 100))
        conf["window_startup"] = {
            "window_size_width": int(gameResolution["width"]),
            "window_size_height": int(gameResolution["height"]),
            "window_position_x": 0,
            "window_position_y": 0,
            "window_maximized": True
        }

        # set ryujinx app language
        conf["language_code"] = getLangFromEnvironment()

        # Console language
        conf["system_language"] = system.config.get("ryujinx_language", "AmericanEnglish")

        # Console region
        conf["system_region"] = system.config.get("ryujinx_region", "USA")

        # Timezone offset
        conf["system_time_zone"] = "UTC"
        conf["system_time_offset"] = system.config.get_int("ryujinx_timeoffset", 0)

        # Docked mode
        conf["docked_mode"] = system.config.get_bool("ryujinx_docked_mode", True)

        # ==================== GRAPHICS ====================
        # Graphics backend
        graphics_backend = _graphics_backend(system.config.get("ryujinx_api", "Vulkan"))
        conf["graphics_backend"] = graphics_backend

        # Internal resolution scale
        _set_resolution_scale(conf, system.config.get("ryujinx_scale", "1"))

        # Aspect ratio
        conf["aspect_ratio"] = system.config.get("ryujinx_ratio", "Fixed16x9")

        # Anisotropic filtering
        conf["max_anisotropy"] = system.config.get_int("ryujinx_filtering", -1)

        # VSync mode
        vsync_mode = _vsync_mode(system.config.get("ryujinx_vsync", "Switch"))
        conf["enable_vsync"] = vsync_mode != 1
        conf["vsync_mode"] = vsync_mode
        conf["enable_custom_vsync_interval"] = vsync_mode == 2
        conf["custom_vsync_interval"] = system.config.get_int("ryujinx_custom_vsync_interval", 120)

        # Backend threading + shader cache.
        # Vulkan can use a combined ES toggle for async GPU/shader behavior.
        async_gpu_shader = system.config.get("ryujinx_async_gpu_shader", "")
        if graphics_backend == "Vulkan" and async_gpu_shader in ("true", "false", "1", "0"):
            enable_async_gpu_shader = async_gpu_shader in ("true", "1")
            conf["backend_threading"] = "Auto" if enable_async_gpu_shader else "Off"
            conf["enable_shader_cache"] = enable_async_gpu_shader
        else:
            conf["backend_threading"] = _backend_threading(system.config.get("ryujinx_backend_threading", "Auto"))
            conf["enable_shader_cache"] = system.config.get_bool("ryujinx_shader_cache", True)

        # Scaling filter
        conf["scaling_filter"] = _choice(
            system.config.get("ryujinx_scaling_filter", "Bilinear"),
            {"Bilinear", "Nearest", "Fsr", "Area"},
            "Bilinear",
        )
        conf["scaling_filter_level"] = system.config.get_int("ryujinx_scaling_filter_level", 80)

        # Anti-aliasing
        conf["anti_aliasing"] = _choice(
            system.config.get("ryujinx_antialiasing", "None"),
            {"None", "Fxaa", "SmaaLow", "SmaaMedium", "SmaaHigh", "SmaaUltra"},
            "None",
        )

        # Texture recompression
        conf["enable_texture_recompression"] = system.config.get_bool("ryujinx_texture_recompression", False)
        conf["enable_macro_hle"] = system.config.get_bool("ryujinx_macro_hle", True)
        conf["enable_color_space_passthrough"] = system.config.get_bool("ryujinx_color_space_passthrough", False)

        # ==================== EMULATION ====================
        # Enable PPTC (Profiled Persistent Translation Cache)
        conf["enable_ptc"] = system.config.get_bool("ryujinx_enable_ptc", True)
        conf["enable_low_power_ptc"] = system.config.get_bool("ryujinx_low_power_ptc", False)

        # FS integrity checks
        conf["enable_fs_integrity_checks"] = system.config.get_bool("ryujinx_fs_integrity", True)

        # Memory manager mode
        conf["memory_manager_mode"] = _choice(
            system.config.get("ryujinx_memory_manager", "HostMappedUnsafe"),
            {"SoftwarePageTable", "HostMapped", "HostMappedUnsafe"},
            "HostMappedUnsafe",
        )
        conf["dram_size"] = _dram_size(system.config.get("ryujinx_dram_size", "MemoryConfiguration4GiB"))
        conf["tick_scalar"] = system.config.get_int("ryujinx_tick_scalar", 100)

        # Ignore missing services
        conf["ignore_missing_services"] = system.config.get_bool("ryujinx_ignore_missing", False)
        conf["ignore_applet"] = system.config.get_bool("ryujinx_ignore_applet", False)

        # ==================== AUDIO ====================
        # Audio backend
        conf["audio_backend"] = _choice(
            system.config.get("ryujinx_audio_backend", "OpenAl"),
            {"Dummy", "OpenAl", "SoundIo", "SDL2"},
            "OpenAl",
        )

        # ==================== NETWORK ====================
        # Multiplayer/LAN mode
        network_mode = system.config.get("ryujinx_network", "no")
        if network_mode == "local":
            conf["multiplayer_mode"] = 1
            conf["multiplayer_lan_interface_id"] = "0"
        elif network_mode == "internet":
            conf["multiplayer_mode"] = 2
        else:
            conf["multiplayer_mode"] = 0
        conf["enable_internet_access"] = system.config.get_bool("ryujinx_internet", False)
        conf.setdefault("hotkeys", {}).update({
            "show_ui": "F4",
            "pause": "F5",
            "screenshot": "F8",
            "toggle_mute": "F2",
            "turbo_mode": "F6",
            "turbo_mode_while_held": False,
        })

        conf["input_config"] = []

        # write / update the config file
        js_out = json.dumps(conf, indent=2)
        with ryujinxConfFile.open("w") as jout:
            jout.write(js_out)

        # Now add Controllers
        for nplayer, pad in enumerate(playersControllers[:8], start=1):
            ctrlConf = ryujinxCtrl.copy()
            # Deep copy the nested dicts
            ctrlConf["left_joycon_stick"] = ryujinxCtrl["left_joycon_stick"].copy()
            ctrlConf["right_joycon_stick"] = ryujinxCtrl["right_joycon_stick"].copy()
            ctrlConf["motion"] = ryujinxCtrl["motion"].copy()
            ctrlConf["rumble"] = ryujinxCtrl["rumble"].copy()
            ctrlConf["left_joycon"] = ryujinxCtrl["left_joycon"].copy()
            ctrlConf["right_joycon"] = ryujinxCtrl["right_joycon"].copy()

            # Shared per-player settings
            padtype_key = f"ryujinx_padtype{nplayer}"
            ctrlConf["controller_type"] = _choice(
                system.config.get(padtype_key, system.config.get("ryujinx_padtype", "ProController")),
                {"ProController", "JoyconPair", "JoyconLeft", "JoyconRight"},
                "ProController",
            )
            ctrlConf["player_index"] = f"Player{nplayer}"
            ctrlConf["deadzone_left"] = system.config.get_float("ryujinx_deadzone_left", 0)
            ctrlConf["deadzone_right"] = system.config.get_float("ryujinx_deadzone_right", 0)
            ctrlConf["rumble"]["enable_rumble"] = system.config.get_bool("ryujinx_rumble", True)
            ctrlConf["motion"]["enable_motion"] = system.config.get_bool("ryujinx_motion", True)
            if nplayer == 1 and (dsu_server := get_dsu_server()):
                host, port = dsu_server
                ctrlConf["motion"] = {
                    "motion_backend": "CemuHook",
                    "sensitivity": 100,
                    "gyro_deadzone": 1,
                    "enable_motion": system.config.get_bool("ryujinx_motion", True),
                    "slot": 0,
                    "alt_slot": 0,
                    "mirror_input": True,
                    "dsu_server_host": host,
                    "dsu_server_port": port,
                }

            if system.config.get_bool("ryujinx_gamepadbuttons"):
                ctrlConf["right_joycon"]["button_a"] = "A"
                ctrlConf["right_joycon"]["button_b"] = "B"
                ctrlConf["right_joycon"]["button_x"] = "X"
                ctrlConf["right_joycon"]["button_y"] = "Y"

            ctrlConf["id"] = _build_ryujinx_controller_id(pad, nplayer)
            ctrlConf["name"] = pad.real_name or pad.name
            writeControllerIntoJson(ctrlConf)

        # ---- Ensure vm.max_map_count is high enough for Ryujinx ----
        VMREQ = 1048576  # future-proof (1M)
        try:
            current_vm = int(subprocess.check_output(
                ["sysctl", "-n", "vm.max_map_count"]
            ).decode().strip())

            if current_vm < VMREQ:
                subprocess.run(
                    ["sysctl", "-w", f"vm.max_map_count={VMREQ}"],
                    check=False
                )
        except Exception:
            pass

        # ---- UCLAMP performance tuning for big.LITTLE ----
        use_uclamp = system.config.get_bool("perf_uclamp", True)
        uclamp_min = system.config.get_int("perf_uclamp_min", UCLAMP_MIN)

        launch_args: list[str] = []
        if not configure_emulator(rom):
            if conf.get("start_fullscreen", True):
                launch_args.append("--fullscreen")

        if configure_emulator(rom):
            base_command = [ryujinxExec]
        else:
            base_command = [ryujinxExec, *launch_args, rom]

        wrapper_path = ryujinxConf / "ryujinx-launch.sh"
        RyujinxGenerator._write_runtime_wrapper(
            wrapper_path,
            str(ryujinxExec),
            use_uclamp=use_uclamp,
            uclamp_min=uclamp_min,
            uclamp_max=UCLAMP_MAX,
            force_fullscreen_toggle=(
                system.config.get_bool("ryujinx_force_fullscreen_toggle", True)
                and bool(conf.get("start_fullscreen", True) and not configure_emulator(rom))
            ),
        )
        if configure_emulator(rom):
            commandArray = [str(wrapper_path)]
        else:
            commandArray = [str(wrapper_path), *launch_args, rom]

        xdg_open_wrapper = ryujinxConf / "xdg-open"
        RyujinxGenerator._write_xdg_open_wrapper(xdg_open_wrapper)
        xdg_path = f"{ryujinxConf}:/sbin:/usr/sbin:/bin:/usr/bin"

        env = {"XDG_CONFIG_HOME": CONFIGS,
            "XDG_DATA_HOME": SAVES / "switch",
            "XDG_CACHE_HOME": CACHE,
            "XDG_MENU_PREFIX": "batocera-",
            "XDG_CONFIG_DIRS": "/etc/xdg",
            "XDG_CURRENT_DESKTOP": "XFCE",
            "DESKTOP_SESSION": "XFCE",
            "PATH": xdg_path,
            "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
            "SDL_JOYSTICK_HIDAPI": "0"
        }
        if graphics_backend == "Vulkan":
            lsfg.apply_lsfg_vk(system, env, process_names=["ryujinx", "Ryujinx"], config_name="ryujinx")

        return Command.Command(array=commandArray, env=env)

    @staticmethod
    def _write_runtime_wrapper(
        wrapper_path: Path,
        executable: str,
        *,
        use_uclamp: bool,
        uclamp_min: int,
        uclamp_max: int,
        force_fullscreen_toggle: bool,
    ):
        """
        Creates a wrapper script that can apply UCLAMP values and force the
        Ryujinx XWayland window to fill the display when start_fullscreen is
        ignored.
        """
        script_content = f'''#!/bin/bash
# Auto-generated runtime wrapper for Ryujinx

EXEC="{executable}"
USE_UCLAMP={1 if use_uclamp else 0}
UCLAMP_MIN={uclamp_min}
UCLAMP_MAX={uclamp_max}
FORCE_FULLSCREEN_TOGGLE={1 if force_fullscreen_toggle else 0}

# SDL is only used by Ryujinx's gamepad driver here. Batocera's session can
# export pulseaudio, but this SDL2 build only ships alsa/dummy audio drivers.
export SDL_AUDIODRIVER="${{RYUJINX_SDL_AUDIODRIVER:-dummy}}"

# Launch emulator in background
"$EXEC" "$@" &
EMU_PID=$!

# Apply UCLAMP settings to main process and all threads
apply_uclamp() {{
    local pid=$1
    if [ -d "/proc/$pid" ]; then
        # Main process
        [ -e /proc/$pid/sched_util_min ] && echo $UCLAMP_MIN > /proc/$pid/sched_util_min
        [ -e /proc/$pid/sched_util_max ] && echo $UCLAMP_MAX > /proc/$pid/sched_util_max

        # All threads
        for tid in /proc/$pid/task/*/; do
            tid=$(basename "$tid")
            [ -e /proc/$pid/task/$tid/sched_util_min ] && echo $UCLAMP_MIN > /proc/$pid/task/$tid/sched_util_min
            [ -e /proc/$pid/task/$tid/sched_util_max ] && echo $UCLAMP_MAX > /proc/$pid/task/$tid/sched_util_max
        done
    fi
}}

if [ "$USE_UCLAMP" = "1" ]; then
    sleep 0.2
    apply_uclamp $EMU_PID
fi

if [ "$FORCE_FULLSCREEN_TOGGLE" = "1" ]; then
    (
        sleep 3
        if command -v xdotool >/dev/null 2>&1 && [ -n "${{DISPLAY:-}}" ]; then
            for _attempt in $(seq 1 20); do
                _display_geometry="$(xdotool getdisplaygeometry 2>/dev/null || true)"
                _width="${{_display_geometry%% *}}"
                _height="${{_display_geometry##* }}"
                if [ -n "$_width" ] && [ -n "$_height" ] && [ "$_width" != "$_height" ]; then
                    _windows="$(xdotool search --onlyvisible --name "Ryujinx" 2>/dev/null || true)"
                    if [ -n "$_windows" ]; then
                        for _window in $_windows; do
                            xdotool windowmove "$_window" 0 0 windowsize "$_window" "$_width" "$_height" >/dev/null 2>&1 || true
                        done
                        break
                    fi
                fi
                sleep 0.5
            done
        elif command -v wtype >/dev/null 2>&1 && [ -n "${{WAYLAND_DISPLAY:-}}" ]; then
            wtype -k F11 >/dev/null 2>&1 || true
        fi
    ) &
    FULLSCREEN_PID=$!
else
    FULLSCREEN_PID=""
fi

if [ "$USE_UCLAMP" = "1" ]; then
    (
        while kill -0 $EMU_PID 2>/dev/null; do
            sleep 2
            apply_uclamp $EMU_PID
        done
    ) &
    MONITOR_PID=$!
else
    MONITOR_PID=""
fi

# Wait for emulator to exit
wait $EMU_PID
EXIT_CODE=$?

# Cleanup monitor
[ -n "$MONITOR_PID" ] && kill $MONITOR_PID 2>/dev/null || true
[ -n "$FULLSCREEN_PID" ] && kill $FULLSCREEN_PID 2>/dev/null || true

exit $EXIT_CODE
'''
        with open(wrapper_path, 'w') as f:
            f.write(script_content)

        os.chmod(wrapper_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)

    @staticmethod
    def _write_xdg_open_wrapper(wrapper_path: Path):
        """
        Ryujinx "Open Folder" uses xdg-open.
        On Batocera, gio can fail to resolve inode/directory handlers.
        This wrapper forces directory targets through filemanagerlauncher.
        """
        script_content = '''#!/bin/sh
set -eu

real_xdg_open="/usr/bin/xdg-open"
target="${1:-}"

if [ -z "$target" ]; then
    exec "$real_xdg_open" "$@"
fi

case "$target" in
    file://*)
        path="${target#file://}"
        ;;
    *)
        path="$target"
        ;;
esac

if [ -d "$path" ]; then
    if command -v filemanagerlauncher >/dev/null 2>&1; then
        exec filemanagerlauncher "$path"
    fi
    if command -v pcmanfm >/dev/null 2>&1; then
        exec pcmanfm "$path"
    fi
fi

exec "$real_xdg_open" "$@"
'''
        with open(wrapper_path, 'w') as f:
            f.write(script_content)

        os.chmod(wrapper_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)


def writeControllerIntoJson(new_controller: dict[str, Any], filename: Path = ryujinxConfFile):
    with filename.open('r+') as file:
        file_data = json.load(file)
        file_data.setdefault("input_config", [])
        file_data["input_config"].append(new_controller)
        file.seek(0)
        json.dump(file_data, file, indent=2)
        file.truncate()

def getLangFromEnvironment():
    lang = environ['LANG'][:5]
    availableLanguages = {"ja_JP", "en_US", "de_DE", "fr_FR", "es_ES", "it_IT", "nl_NL", "zh_CN", "zh_TW", "ko_KR"}
    if lang in availableLanguages:
        return lang
    return "en_US"


def _build_ryujinx_controller_id(pad, nplayer):
    pad_index = _controller_index(pad, nplayer)
    controller_id = _build_ryujinx_controller_id_from_sdl_guid(getattr(pad, "guid", None), pad_index)
    if controller_id is not None:
        return controller_id

    if evdev is None:
        return str(pad_index)

    try:
        devices = [evdev.InputDevice(fn) for fn in evdev.list_devices()]
    except Exception:
        return str(pad_index)

    for dev in devices:
        try:
            if dev.path != pad.device_path:
                continue

            bustype = f"{dev.info.bustype:08x}"
            vendor = f"{dev.info.vendor:04x}"
            product = f"{dev.info.product:04x}"
            version = f"{dev.info.version:04x}"
            product = product[2:] + product[:2]
            version = version[2:] + version[:2]
            return f"{pad_index}-{bustype}-{vendor}-0000-{product}-0000{version}0000"
        except Exception:
            continue

    return str(pad_index)


def _controller_index(pad, nplayer):
    try:
        return int(getattr(pad, "index"))
    except (TypeError, ValueError):
        return nplayer - 1


def _build_ryujinx_controller_id_from_sdl_guid(guid, pad_index):
    if not guid:
        return None

    guid = str(guid).replace("-", "").lower()
    if len(guid) != 32:
        return None

    try:
        guid_bytes = bytes.fromhex(guid)
    except ValueError:
        return None

    bus = int.from_bytes(guid_bytes[0:4], "little")
    vendor = int.from_bytes(guid_bytes[4:6], "little")
    if bus == 0 or vendor == 0:
        return None

    # Ryujinx's SDL2 driver converts SDL GUIDs through System.Guid and then
    # prefixes a duplicate index. The product/version fields are kept in SDL's
    # byte order here to match that string form.
    product = guid_bytes[8:10].hex()
    version = guid_bytes[12:14].hex()
    return f"{pad_index}-{bus:08x}-{vendor:04x}-0000-{product}-0000{version}0000"


def _link_dir_into_expected(source_dir, expected_dir):
    if not source_dir.exists():
        return

    if expected_dir.is_symlink():
        try:
            if expected_dir.resolve() == source_dir.resolve():
                return
        except FileNotFoundError:
            pass
        expected_dir.unlink(missing_ok=True)
        expected_dir.symlink_to(source_dir, target_is_directory=True)
        return

    if expected_dir.exists():
        return

    expected_dir.parent.mkdir(parents=True, exist_ok=True)
    expected_dir.symlink_to(source_dir, target_is_directory=True)


def _copy_key_file_into_expected(source_file, expected_file):
    if not source_file.exists():
        return

    if expected_file.is_symlink():
        expected_file.unlink(missing_ok=True)

    if expected_file.exists() and filecmp.cmp(source_file, expected_file, shallow=False):
        return

    expected_file.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_file, expected_file)


def _pick_existing_path(*candidates):
    for path in candidates:
        if path.exists():
            return path
    return None


def _resolve_firmware_dir():
    candidates = (
        switchFirmwareDir / "registered",
        switchFirmwareDir / "Contents" / "registered",
        switchFirmwareDir / "system" / "Contents" / "registered",
    )

    for candidate in candidates:
        if candidate.is_dir():
            return candidate

    if switchFirmwareDir.is_dir() and any(_is_registered_firmware_entry(child) for child in switchFirmwareDir.iterdir()):
        return switchFirmwareDir

    return None


def _is_registered_firmware_entry(path):
    if path.is_file():
        return path.name.endswith(".nca")

    return path.is_dir() and path.name.endswith(".nca") and (path / "00").is_file()


def _registered_firmware_entries(source_dir):
    for child in sorted(source_dir.iterdir()):
        if child.is_file() and child.name.endswith(".nca"):
            yield child, child.name
        elif child.is_dir() and child.name.endswith(".nca") and (child / "00").is_file():
            yield child / "00", child.name


def _prune_stale_firmware_entries(target_registered_dir, expected_names):
    if not target_registered_dir.is_dir():
        return

    for child in target_registered_dir.iterdir():
        if child.name in expected_names:
            continue

        if child.is_symlink() or child.is_file():
            child.unlink()
        elif child.is_dir():
            shutil.rmtree(child)
        else:
            child.unlink(missing_ok=True)


def _bootstrap_firmware_registered_from_firmware_dir(bis_root):
    """
    Shared Switch firmware dumps live in /userdata/bios/switch/firmware.
    Ryujinx expects registered firmware under bis/system/Contents/registered.
    """
    source_dir = _resolve_firmware_dir()
    if source_dir is None:
        return

    registered = bis_root / "system" / "Contents" / "registered"
    registered.mkdir(parents=True, exist_ok=True)

    entries = list(_registered_firmware_entries(source_dir))
    expected_names = {target_name for _, target_name in entries}
    _prune_stale_firmware_entries(registered, expected_names)

    for nca, target_name in entries:
        target_dir = registered / target_name
        target = target_dir / "00"

        # Ryujinx enumerates registered firmware as <content>.nca/00 directories.
        if target_dir.is_symlink() or target_dir.is_file():
            target_dir.unlink(missing_ok=True)
        elif target_dir.exists() and not target_dir.is_dir():
            target_dir.unlink(missing_ok=True)

        target_dir.mkdir(parents=True, exist_ok=True)

        if target.exists() and filecmp.cmp(nca, target, shallow=False):
            continue
        if target.exists() or target.is_symlink():
            target.unlink(missing_ok=True)

        try:
            os.link(nca, target)
        except OSError:
            # Cross-device fallback: copy as a normal file.
            shutil.copy2(nca, target)


def _bootstrap_firmware_registered_from_flat_nand(nand_root, bis_root):
    """
    Some firmware dumps are flattened with *.nca files at NAND root.
    Ryujinx expects firmware content under bis/system/Contents/registered.
    If registered is empty, symlink loose NCAs into that folder.
    """
    if not nand_root.exists():
        return

    registered = bis_root / "system" / "Contents" / "registered"
    registered.mkdir(parents=True, exist_ok=True)

    try:
        if any(registered.iterdir()):
            return
    except OSError:
        return

    loose_ncas = sorted(p for p in nand_root.glob("*.nca") if p.is_file())
    if not loose_ncas:
        return

    for nca in loose_ncas:
        target_dir = registered / nca.name
        target = target_dir / "00"

        if target_dir.is_symlink() or target_dir.is_file():
            target_dir.unlink(missing_ok=True)
        elif target_dir.exists() and not target_dir.is_dir():
            target_dir.unlink(missing_ok=True)

        target_dir.mkdir(parents=True, exist_ok=True)

        if target.exists():
            continue

        try:
            os.link(nca, target)
        except OSError:
            # Cross-device fallback: copy as a normal file.
            shutil.copy2(nca, target)
