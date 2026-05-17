from __future__ import annotations

from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import CACHE, CONFIGS, SAVES, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


class OpengoalGenerator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "opengoal",
            "keys": {
                "exit": ["KEY_LEFTALT", "KEY_F4"],
                "menu": "KEY_ESC",
                "pause": "KEY_ESC"
            }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        opengoalConfigDir = CONFIGS / "opengoal"
        opengoalSaveDir = SAVES / "opengoal"
        opengoalCacheDir = CACHE / "opengoal"

        mkdir_if_not_exists(opengoalConfigDir)
        mkdir_if_not_exists(opengoalSaveDir)
        mkdir_if_not_exists(opengoalCacheDir)

        game = system.config.get("opengoal_game", "auto")
        commandArray = ["/usr/bin/opengoal"]

        if game != "auto":
            commandArray.extend(["--game", game])

        if system.config.get("opengoal_rebuild", "0") == "1":
            commandArray.append("--rebuild")

        if system.config.get("opengoal_no_avx2", "0") == "1":
            commandArray.append("--no-avx2")

        if rom.exists():
            commandArray.append(str(rom))

        audioDriver = system.config.get("opengoal_audio_driver", "pulseaudio")
        env = {
            "XDG_CONFIG_HOME": opengoalConfigDir,
            "XDG_DATA_HOME": opengoalSaveDir,
            "XDG_CACHE_HOME": opengoalCacheDir,
            "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
            "SDL_JOYSTICK_HIDAPI": "0",
            "SDL_AUDIODRIVER": audioDriver,
            "DISABLE_MANGOHUD": "1"
        }

        return Command.Command(array=commandArray, env=env)

    def getMouseMode(self, config, rom):
        return True
