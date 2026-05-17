from __future__ import annotations

from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import CACHE, CONFIGS, SAVES, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


class UnleashedrecompGenerator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "unleashedrecomp",
            "keys": {
                "exit": ["KEY_LEFTALT", "KEY_F4"],
                "menu": "KEY_ESC",
                "pause": "KEY_ESC"
            }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        unleashedConfigDir = CONFIGS / "unleashedrecomp"
        unleashedSaveDir = SAVES / "unleashedrecomp"
        unleashedCacheDir = CACHE / "unleashedrecomp"

        mkdir_if_not_exists(unleashedConfigDir)
        mkdir_if_not_exists(unleashedSaveDir)
        mkdir_if_not_exists(unleashedCacheDir)

        commandArray = ["/usr/bin/unleashedrecomp"]

        mode = system.config.get("unleashedrecomp_launch_mode", "play")
        if mode in ("install", "install-dlc", "install-check"):
            commandArray.append(f"--{mode}")

        videoDriver = system.config.get("unleashedrecomp_sdl_video_driver", "auto")
        if videoDriver != "auto":
            commandArray.extend(["--sdl-video-driver", videoDriver])

        audioDriver = system.config.get("unleashedrecomp_audio_driver", "pulseaudio")
        env = {
            "XDG_CONFIG_HOME": unleashedConfigDir,
            "XDG_DATA_HOME": unleashedSaveDir,
            "XDG_CACHE_HOME": unleashedCacheDir,
            "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
            "SDL_JOYSTICK_HIDAPI": "0",
            "SDL_AUDIODRIVER": audioDriver,
            "DISABLE_MANGOHUD": "1"
        }

        return Command.Command(array=commandArray, env=env)

    def getMouseMode(self, config, rom):
        return True
