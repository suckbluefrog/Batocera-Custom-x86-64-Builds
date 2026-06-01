from __future__ import annotations

import re
from pathlib import Path
from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import BIOS, CACHE, CONFIGS, HOME, SAVES
from ...controller import generate_sdl_game_controller_config, write_sdl_controller_db
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


_VM_ROOT = SAVES / "86box"
_DEFAULT_ROM_PATH = BIOS / "86box"
_DISK_IMAGE_EXTENSIONS = {".dsk", ".flp", ".ima", ".img", ".vfd"}


def _clean_name(name: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", name).strip("._")
    return cleaned or "vm"


def _is_config_launch(rom: Path) -> bool:
    return str(rom) == "config" or rom.name == "config"


def _vm_path_for_rom(rom: Path) -> Path:
    if rom.is_dir():
        return rom

    if rom.suffix.lower() == ".cfg":
        return rom.parent

    return _VM_ROOT / _clean_name(rom.stem)


class Box86Generator(Generator):
    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "86box",
            "keys": {"exit": ["KEY_LEFTALT", "KEY_F4"]},
        }

    def getMouseMode(self, config, rom: Path) -> bool:
        return True

    def generate(self, system, rom: Path, playersControllers, metadata, guns, wheels, gameResolution):
        _VM_ROOT.mkdir(parents=True, exist_ok=True)
        CONFIGS.mkdir(parents=True, exist_ok=True)
        CACHE.mkdir(parents=True, exist_ok=True)
        write_sdl_controller_db(playersControllers)

        command = ["/usr/bin/86Box"]

        if system.config.get_bool("86box_fullscreen", True):
            command.append("--fullscreen")

        if system.config.get_bool("86box_no_confirm", True):
            command.append("--noconfirm")

        if system.config.get_bool("86box_settings_only"):
            command.append("--settings")

        if system.config.get_str("86box_keyboard_hook", "enabled") == "nohook":
            command.append("--nohook")

        clear_nvram = system.config.get_str("86box_clear_nvram", "").strip()
        if clear_nvram in {"cmos", "flash", "both"}:
            command.extend(["--clear", clear_nvram])

        language = system.config.get_str("86box_language", "system").strip()
        if language:
            command.extend(["--lang", language])

        rom_path = system.config.get_str("86box_rom_path", str(_DEFAULT_ROM_PATH)).strip()
        if rom_path:
            Path(rom_path).mkdir(parents=True, exist_ok=True)
            command.extend(["--rompath", rom_path])

        global_config = system.config.get_str("86box_global_config", "").strip()
        if global_config:
            command.extend(["--global", global_config])

        vm_name = system.config.get_str("86box_vm_name", "").strip()
        if vm_name:
            command.extend(["--vmname", vm_name])

        if not _is_config_launch(rom):
            vm_path = _vm_path_for_rom(rom)
            vm_path.mkdir(parents=True, exist_ok=True)
            command.extend(["--vmpath", vm_path])

            config_path = rom if rom.suffix.lower() == ".cfg" else vm_path / "86box.cfg"
            if config_path.is_file():
                command.extend(["--config", config_path])

            if rom.suffix.lower() in _DISK_IMAGE_EXTENSIONS:
                drive = system.config.get_str("86box_floppy_drive", "A").strip().upper()
                if drive not in {"A", "B"}:
                    drive = "A"
                command.extend(["--image", f"{drive}:{rom}"])

        return Command.Command(
            array=command,
            env={
                "HOME": HOME,
                "XDG_CONFIG_HOME": CONFIGS,
                "XDG_DATA_HOME": _VM_ROOT,
                "XDG_CACHE_HOME": CACHE,
                "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
                "SDL_JOYSTICK_HIDAPI": "0",
            },
        )
