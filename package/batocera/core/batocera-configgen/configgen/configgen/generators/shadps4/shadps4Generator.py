#
# This file is part of the batocera distribution (https://batocera.org).
# Copyright (c) 2025+.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# YOU MUST KEEP THIS HEADER AS IT IS
#
from __future__ import annotations

import json
import logging
import os
import sys
from pathlib import Path
import shutil
from typing import TYPE_CHECKING, Any

import toml

from ... import Command
from ...batoceraPaths import CONFIGS, configure_emulator, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ...utils import vulkan
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext

_logger = logging.getLogger(__name__)

_SHADPS4_DEFAULT_USERS: dict[str, Any] = {
    "Users": {
        "user": [
            {
                "user_id": 1000,
                "user_color": 1,
                "user_name": "shadPS4",
                "player_index": 1,
                "shadnet_npid": "",
                "shadnet_password": "",
                "shadnet_token": "",
                "shadnet_email": "",
                "shadnet_enabled": False,
            },
            {
                "user_id": 1001,
                "user_color": 2,
                "user_name": "shadPS4-2",
                "player_index": 2,
                "shadnet_npid": "",
                "shadnet_password": "",
                "shadnet_token": "",
                "shadnet_email": "",
                "shadnet_enabled": False,
            },
            {
                "user_id": 1002,
                "user_color": 3,
                "user_name": "shadPS4-3",
                "player_index": 3,
                "shadnet_npid": "",
                "shadnet_password": "",
                "shadnet_token": "",
                "shadnet_email": "",
                "shadnet_enabled": False,
            },
            {
                "user_id": 1003,
                "user_color": 4,
                "user_name": "shadPS4-4",
                "player_index": 4,
                "shadnet_npid": "",
                "shadnet_password": "",
                "shadnet_token": "",
                "shadnet_email": "",
                "shadnet_enabled": False,
            },
        ],
        "commit_hash": "GITDIR-NOTFOUND",
    }
}


def _load_json_file(path: Path) -> dict[str, Any]:
    if path.is_file():
        try:
            with path.open(encoding="utf-8") as json_file:
                data = json.load(json_file)
            if isinstance(data, dict):
                return data
        except Exception as e:
            _logger.warning("Failed to load shadps4 JSON config %s: %s", path, e)

    return {}


def _write_json_file(path: Path, data: dict[str, Any]) -> None:
    with path.open("w", encoding="utf-8") as json_file:
        json.dump(data, json_file, indent=2)
        json_file.write("\n")


def _ensure_users_json(userConfigPath: Path) -> None:
    users_file = userConfigPath / "users.json"
    users = _load_json_file(users_file)
    users_section = users.get("Users")

    if isinstance(users_section, dict) and isinstance(users_section.get("user"), list):
        return

    _logger.info("Creating default shadps4 users at %s", users_file)
    _write_json_file(users_file, _SHADPS4_DEFAULT_USERS)

    for user_id in ("1000", "1001", "1002", "1003"):
        for subdir in ("savedata", "trophy", "inputs"):
            mkdir_if_not_exists(userConfigPath / "home" / user_id / subdir)


def _update_v016_config_json(
    json_file: Path,
    system,
    gameResolution,
    romDir: Path,
    dlcPath: Path,
    discrete_index: int,
) -> None:
    config = _load_json_file(json_file)

    general_config = config.setdefault("General", {})
    general_config["install_dirs"] = [{"path": str(romDir), "enabled": True}]
    general_config["addon_install_dir"] = str(dlcPath)
    general_config["discord_rpc_enabled"] = False
    general_config["neo_mode"] = system.config.get_bool("shadps4_ps4pro", False)
    general_config["show_splash"] = system.config.get_bool("shadps4_show_splash", False)
    general_config["console_language"] = int(system.config.get("shadps4_console_lang", 1))

    input_config = config.setdefault("Input", {})
    input_config["motion_controls_enabled"] = True
    input_config["use_unified_input_config"] = True

    gpu_config = config.setdefault("GPU", {})
    gpu_config["window_width"] = int(gameResolution["width"])
    gpu_config["window_height"] = int(gameResolution["height"])
    gpu_config["full_screen"] = True
    gpu_config["full_screen_mode"] = "Fullscreen (Borderless)"
    gpu_config["hdr_allowed"] = system.config.get_bool("shadps4_hdr", False)
    gpu_config["copy_gpu_buffers"] = system.config.get_bool("shadps4_copy_gpu_buffers", False)
    gpu_config["patch_shaders"] = system.config.get_bool("shadps4_patch_shaders", True)

    vulkan_config = config.setdefault("Vulkan", {})
    vulkan_config["gpu_id"] = int(discrete_index)
    vulkan_config["vkvalidation_enabled"] = False
    vulkan_config["vkvalidation_sync_enabled"] = False
    vulkan_config["vkvalidation_gpu_enabled"] = False
    vulkan_config["vkcrash_diagnostic_enabled"] = False
    vulkan_config["vkhost_markers"] = False
    vulkan_config["vkguest_markers"] = False

    _write_json_file(json_file, config)


class shadPS4Generator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "shadps4",
            "keys": {"exit": ["KEY_LEFTALT", "KEY_F4"]}
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):

        # Set the paths using Path objects
        configPath = CONFIGS / "shadps4"
        userConfigPath = configPath / "user"
        customTrophyPath = userConfigPath / "custom_trophy"
        toml_file = userConfigPath / "config.toml"
        json_file = userConfigPath / "config.json"
        savesPath = Path("/userdata/saves/shadps4")
        romDir = Path("/userdata/roms/ps4")
        dlcPath = romDir / "DLC"
        trophySoundSource = Path("/usr/share/libretro/assets/sounds/ps3-trophy.wav")
        trophySoundTarget = customTrophyPath / "trophy.wav"

        mkdir_if_not_exists(userConfigPath)
        mkdir_if_not_exists(customTrophyPath)
        mkdir_if_not_exists(savesPath)

        # Check Vulkan first before doing anything
        discrete_index = -1
        if vulkan.is_available():
            _logger.debug("Vulkan driver is available on the system.")
            vulkan_version = vulkan.get_version()
            if vulkan_version > "1.3":
                _logger.debug("Using Vulkan version: %s", vulkan_version)
                if vulkan.has_discrete_gpu():
                    _logger.debug("A discrete GPU is available on the system. We will use that for performance")
                    discrete_index = vulkan.get_discrete_gpu_index()
                    if discrete_index:
                        _logger.debug("Using Discrete GPU Index: %s for shadPS4", discrete_index)
                    else:
                        _logger.debug("Couldn't get discrete GPU index")
                        discrete_index = 0
                else:
                    _logger.debug("Discrete GPU is not available on the system. Using default.")
            else:
                _logger.debug("Vulkan version: %s is not compatible with shadPS4", vulkan_version)
        else:
            _logger.debug("*** Vulkan driver required is not available on the system!!! ***")
            sys.exit(1)

        # Adjust the config.toml file
        config: dict[str, dict[str, object]] = {}

        # Check if the file exists
        if toml_file.is_file():
            try:
                with toml_file.open("r") as f:
                    config = toml.load(f)
            except Exception as e:
                 _logger.error("Failed to load existing shadps4 config: %s. Will create default.", e)

        # If config is empty, create default structure
        if not config:
             _logger.info("Creating default shadps4 config at %s", toml_file)
             config = {
                "General": {
                    "isPS4Pro": False,
                    "isTrophyPopupDisabled": False,
                    "trophyNotificationDuration": 6.0,
                    "playBGM": False,
                    "BGMvolume": 50,
                    "enableDiscordRPC": False,
                    "logFilter": "",
                    "logType": "async",
                    "userName": "Batocera",
                    "updateChannel": "Release",
                    "chooseHomeTab": "General",
                    "showSplash": False,
                    "autoUpdate": False,
                    "alwaysShowChangelog": False,
                    "sideTrophy": "right",
                    "separateUpdateEnabled": False,
                    "compatibilityEnabled": False,
                    "checkCompatibilityOnStartup": False,
                },
                "Input": {
                    "cursorState": 1,
                    "cursorHideTimeout": 5,
                    "backButtonBehavior": "left",
                    "useSpecialPad": False,
                    "specialPadClass": 1,
                    "isMotionControlsEnabled": True,
                    "useUnifiedInputConfig": True,
                },
                "GPU": {
                    "screenWidth": int(gameResolution["width"]),
                    "screenHeight": int(gameResolution["height"]),
                    "nullGpu": False,
                    "copyGPUBuffers": False,
                    "dumpShaders": False,
                    "patchShaders": True,
                    "vblankDivider": 1,
                    "Fullscreen": True,
                    "FullscreenMode": "Fullscreen (Borderless)",
                    "allowHDR": False,
                },
                "Vulkan": {
                    "gpuId": int(discrete_index),
                    "validation": False,
                    "validation_sync": False,
                    "validation_gpu": False,
                    "crashDiagnostic": False,
                    "hostMarkers": False,
                    "guestMarkers": False,
                    "rdocEnable": False,
                },
                "Debug": {
                    "DebugDump": False,
                    "CollectShader": False,
                    "isSeparateLogFilesEnabled": False,
                    "FPSColor": True,
                },
                "Keys": {
                    "TrophyKey": ""
                 },
                "GUI": {
                    "installDirs": [str(romDir)],
                    "saveDataPath": str(savesPath),
                    "loadGameSizeEnabled": True,
                    "addonInstallDir": str(dlcPath),
                    "emulatorLanguage": "en_US",
                    "backgroundImageOpacity": 50,
                    "showBackgroundImage": True,
                    "mw_width": int(gameResolution["width"]),
                    "mw_height": int(gameResolution["height"]),
                    "theme": 0,
                    "iconSize": 36,
                    "sliderPos": 0,
                    "iconSizeGrid": 69,
                    "sliderPosGrid": 0,
                    "gameTableMode": 0,
                    "geometry_x": 0,
                    "geometry_y": 0,
                    "geometry_w": int(gameResolution["width"]),
                    "geometry_h": int(gameResolution["height"]),
                    "pkgDirs": [str(romDir)],
                    "elfDirs": [],
                    "recentFiles": [],
                },
                "Settings": {
                    "consoleLanguage": 1
                },
             }

        # --- Apply Batocera Specific Overrides ---
        # General
        general_config = config.setdefault("General", {})
        general_config["autoUpdate"] = False
        general_config["enableDiscordRPC"] = False
        general_config["userName"] = "Batocera"

        # GPU
        gpu_config = config.setdefault("GPU", {})
        gpu_config["Fullscreen"] = True
        gpu_config["FullscreenMode"] = "Fullscreen (Borderless)"
        gpu_config["screenWidth"] = int(gameResolution["width"])
        gpu_config["screenHeight"] = int(gameResolution["height"])

        # GUI
        gui_config = config.setdefault("GUI", {})
        gui_config["addonInstallDir"] = str(dlcPath)
        gui_config["installDirs"] = [str(romDir)]
        gui_config["saveDataPath"] = str(savesPath)
        gui_config["mw_width"] = int(gameResolution["width"])
        gui_config["mw_height"] = int(gameResolution["height"])
        gui_config["geometry_w"] = int(gameResolution["width"])
        gui_config["geometry_h"] = int(gameResolution["height"])
        gui_config["pkgDirs"] = [str(romDir)]

        # Vulkan - Set the detected GPU ID
        config.setdefault("Vulkan", {})["gpuId"] = int(discrete_index)

        # Options
        if system.config.get_bool("shadps4_hdr"):
            gpu_config["allowHDR"] = True
        else:
            gpu_config["allowHDR"] = False
        general_config["isPS4Pro"] = system.config.get_bool("shadps4_ps4pro", False)
        general_config["showSplash"] = system.config.get_bool("shadps4_show_splash", False)
        gpu_config["copyGPUBuffers"] = system.config.get_bool("shadps4_copy_gpu_buffers", False)
        gpu_config["patchShaders"] = system.config.get_bool("shadps4_patch_shaders", True)
        if system.config.get("shadps4_console_lang"):
            config["Settings"]["consoleLanguage"] = int(system.config["shadps4_console_lang"])
        else:
            config["Settings"]["consoleLanguage"] = 1

        # Create necessary directories if they do not exist
        mkdir_if_not_exists(toml_file.parent)
        mkdir_if_not_exists(configPath / "launcher")

        # Seed the Qt custom trophy sound if the user has not overridden it.
        if trophySoundSource.is_file() and not trophySoundTarget.exists():
            shutil.copy2(trophySoundSource, trophySoundTarget)

        # Now write the updated toml
        with toml_file.open("w") as f:
            toml.dump(config, f)

        # shadPS4 v0.16+ loads config.json and blocks on an interactive
        # migration dialog when only the old config.toml exists.
        _update_v016_config_json(
            json_file, system, gameResolution, romDir, dlcPath, discrete_index
        )
        _ensure_users_json(userConfigPath)

        # Change to the configPath directory before running
        os.chdir(configPath)

        # Determine the path based on extension
        if rom.is_dir():
            eboot_path = rom / "eboot.bin"
        else:
            eboot_path = rom.parent / "eboot.bin"

        # Run command
        if configure_emulator(rom):
            commandArray: list[str | Path] = [
                "/usr/bin/shadps4/shadPS4QtLauncher",
                "-e",
                "/usr/bin/shadps4/shadps4",
                "-s",
            ]
        else:
            commandArray: list[str | Path] = ["/usr/bin/shadps4/shadps4", eboot_path]

        return Command.Command(
            array=commandArray,
            env={
                "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
                "SDL_JOYSTICK_HIDAPI": "0"
            }
        )

    def getInGameRatio(self, config, gameResolution, rom):
        return 16 / 9
