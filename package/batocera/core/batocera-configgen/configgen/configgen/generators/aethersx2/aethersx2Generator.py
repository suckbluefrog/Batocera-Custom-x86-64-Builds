from __future__ import annotations

import time
from pathlib import Path
from typing import Final

from ..Generator import Generator
from ... import Command
from ...batoceraPaths import BIOS, SAVES, ensure_parents_and_open
from ...utils.configparser import CaseSensitiveConfigParser

_AETHERSX2_CONFIG: Final = Path("/userdata/system/.config/aethersx2")
_AETHERSX2_INI: Final = _AETHERSX2_CONFIG / "inis" / "PCSX2.ini"
_AETHERSX2_BIN: Final = Path("/usr/bin/aethersx2")


class AetherSX2Generator(Generator):

    def getHotkeysContext(self):
        return {
            "name": "aethersx2",
            "keys": {"exit": ["KEY_LEFTALT", "KEY_F4"]},
        }

    # AetherSX2 crashes if MangoHUD is injected
    def hasInternalMangoHUDCall(self):
        return True

    # Critical: allow emulator to receive raw input
    def getInGameSettings(self, system, rom):
        return {
            "nograb": True
        }

    def generate(self, system, rom, controllers, metadata, guns, wheels, gameResolution):

        ini = CaseSensitiveConfigParser(interpolation=None)
        if _AETHERSX2_INI.exists():
            ini.read(_AETHERSX2_INI)

        def ensure(section: str):
            if not ini.has_section(section):
                ini.add_section(section)

        # ==================== CORE SECTIONS ====================
        ensure("EmuCore")
        ensure("EmuCore/GS")
        ensure("EmuCore/Speedhacks")
        ensure("EmuCore/Gamefixes")
        ensure("SPU2/Mixing")
        ensure("SPU2/Output")
        ensure("Folders")
        ensure("Achievements")

        # ==================== RENDERING ====================
        ini.set("EmuCore/GS", "Renderer",
                system.config.get("aethersx2_renderer", "-1"))

        ini.set("EmuCore/GS", "upscale_multiplier",
                system.config.get("aethersx2_resolution", "1"))

        ini.set("EmuCore/GS", "MaxAnisotropy",
                system.config.get("aethersx2_anisotropic", "0"))

        ini.set("EmuCore/GS", "fxaa",
                system.config.get_bool("aethersx2_fxaa",
                                       return_values=("true", "false")))

        ini.set("EmuCore/GS", "mipmap_hw",
                system.config.get("aethersx2_mipmapping", "-1"))

        ini.set("EmuCore/GS", "texture_preloading",
                system.config.get("aethersx2_texture_preload", "2"))

        ini.set("EmuCore/GS", "accurate_blending_unit",
                system.config.get("aethersx2_blending", "1"))

        # ==================== DISPLAY ====================
        ini.set("EmuCore/GS", "AspectRatio",
                system.config.get("aethersx2_aspect_ratio", "4:3"))

        ini.set("EmuCore/GS", "filter",
                system.config.get("aethersx2_bilinear", "2"))

        ini.set("EmuCore/GS", "VsyncEnable",
                system.config.get("aethersx2_vsync", "0"))

        ini.set("EmuCore/GS", "deinterlace_mode",
                system.config.get("aethersx2_deinterlace", "0"))

        ini.set("EmuCore/GS", "dithering_ps2",
                system.config.get("aethersx2_dithering", "2"))

        ini.set("EmuCore/GS", "IntegerScaling",
                system.config.get_bool("aethersx2_integer_scaling",
                                       return_values=("true", "false")))

        ini.set("EmuCore/GS", "OsdShowFPS",
                system.config.get_bool("aethersx2_show_fps",
                                       return_values=("true", "false")))

        # ==================== SPEEDHACKS ====================
        ini.set("EmuCore/Speedhacks", "EECycleRate",
                system.config.get("aethersx2_ee_cycle_rate", "0"))

        ini.set("EmuCore/Speedhacks", "EECycleSkip",
                system.config.get("aethersx2_ee_cycle_skip", "0"))

        ini.set("EmuCore/GS", "HWDownloadMode",
                system.config.get("aethersx2_hw_download", "0"))

        ini.set("EmuCore/Speedhacks", "vuThread",
                system.config.get_bool("aethersx2_mtvu", True,
                                       return_values=("true", "false")))

        ini.set("EmuCore/Speedhacks", "vu1Instant",
                system.config.get_bool("aethersx2_instant_vu1", True,
                                       return_values=("true", "false")))

        ini.set("EmuCore/Speedhacks", "fastCDVD",
                system.config.get_bool("aethersx2_fast_cdvd",
                                       return_values=("true", "false")))

        # ==================== SYSTEM ====================
        ini.set("EmuCore", "EnableFastBoot",
                system.config.get_bool("aethersx2_fastboot", True,
                                       return_values=("true", "false")))

        ini.set("EmuCore", "EnableWideScreenPatches",
                system.config.get_bool("aethersx2_widescreen",
                                       return_values=("true", "false")))

        ini.set("EmuCore", "EnableNoInterlacingPatches",
                system.config.get_bool("aethersx2_nointerlace_patches",
                                       return_values=("true", "false")))

        ini.set("EmuCore", "EnableCheats",
                system.config.get_bool("aethersx2_cheats",
                                       return_values=("true", "false")))

        ini.set("EmuCore", "EnableGameFixes",
                system.config.get_bool("aethersx2_game_fixes", True,
                                       return_values=("true", "false")))

        # ==================== AUDIO ====================
        ini.set("SPU2/Mixing", "Interpolation",
                system.config.get("aethersx2_audio_interpolation", "5"))

        ini.set("SPU2/Output", "Latency",
                system.config.get("aethersx2_audio_latency", "100"))

        # ==================== RETROACHIEVEMENTS ====================
        ini.set("Achievements", "Enabled", "false")
        ini.set("Achievements", "Notifications", "true")
        ini.set("Achievements", "SoundEffects", "true")

        if system.config.get_bool("retroachievements"):
            ini.set("Achievements", "Enabled", "true")
            ini.set("Achievements", "Username",
                    system.config.get("retroachievements.username", ""))
            ini.set("Achievements", "Token",
                    system.config.get("retroachievements.token", ""))
            ini.set("Achievements", "LoginTimestamp",
                    str(int(time.time())))
            ini.set("Achievements", "ChallengeMode",
                    system.config.get_bool("retroachievements.hardcore",
                                           return_values=("true", "false")))

        # ==================== PATHS ====================
        ini.set("Folders", "Bios", str(BIOS / "ps2"))
        ini.set("Folders", "Savestates", str(SAVES / "ps2"))
        ini.set("Folders", "MemoryCards", str(SAVES / "ps2"))

        # ==================== WRITE CONFIG ====================
        with ensure_parents_and_open(_AETHERSX2_INI, "w") as f:
            ini.write(f)

        return Command.Command(
            array=[str(_AETHERSX2_BIN), "-fullscreen", str(rom)],
            env={
                "XDG_CONFIG_HOME": "/userdata/system/.config",
            },
        )
