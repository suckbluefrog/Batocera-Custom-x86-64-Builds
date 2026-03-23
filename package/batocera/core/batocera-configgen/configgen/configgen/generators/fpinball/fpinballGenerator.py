from __future__ import annotations

import logging
import os
import shutil
import subprocess
from pathlib import Path, PureWindowsPath
from typing import TYPE_CHECKING, Final

from ... import Command
from ...batoceraPaths import CONFIGS, HOME, mkdir_if_not_exists
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext

eslog = logging.getLogger(__name__)

_FPINBALL_CONFIG: Final = CONFIGS / "fpinball"
_FPINBALL_CONFIG_REG: Final = _FPINBALL_CONFIG / "batocera.confg.reg"


class FpinballGenerator(Generator):
    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "fpinball",
            "keys": {"exit": ["KEY_LEFTALT", "KEY_F4"]},
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        wineprefix = HOME / "wine-bottles" / "fpinball"
        emupath = wineprefix / "fpinball"

        mkdir_if_not_exists(wineprefix)

        wsh57_done = wineprefix / "wsh57.done"
        if not wsh57_done.exists():
            cmd = ["/usr/wine/winetricks", "-q", "wsh57"]
            env = {
                "W_CACHE": "/userdata/bios",
                "LD_LIBRARY_PATH": "/lib32:/usr/wine/wine-tkg/lib/wine",
                "WINEPREFIX": wineprefix,
            }
            env.update(os.environ)
            env["PATH"] = "/usr/wine/wine-tkg/bin:/bin:/usr/bin"
            proc = subprocess.Popen(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            out, err = proc.communicate()
            eslog.debug(out.decode())
            eslog.error(err.decode())
            with wsh57_done.open("w") as f:
                f.write("done")

        if not emupath.exists():
            shutil.copytree("/usr/fpinball", emupath)

        src_file = Path("/usr/fpinball/BAM/FPLoader.exe")
        dest_file = emupath / "BAM" / "FPLoader.exe"
        if src_file.exists() and dest_file.exists() and src_file.stat().st_mtime > dest_file.stat().st_mtime:
            shutil.copytree("/usr/fpinball", emupath, dirs_exist_ok=True)

        rompath = PureWindowsPath(rom)
        if rom == "config":
            commandArray = [
                "/usr/wine/wine-tkg/bin/wine",
                "explorer",
                f"/desktop=Wine,{gameResolution['width']}x{gameResolution['height']}",
                emupath / "BAM" / "FPLoader.exe",
            ]
        else:
            commandArray = [
                "/usr/wine/wine-tkg/bin/wine",
                "explorer",
                f"/desktop=Wine,{gameResolution['width']}x{gameResolution['height']}",
                emupath / "BAM" / "FPLoader.exe",
                "/open", f"Z:{rompath}", "/play", "/exit",
            ]

        mkdir_if_not_exists(_FPINBALL_CONFIG)
        with _FPINBALL_CONFIG_REG.open("w") as f:
            f.write("Windows Registry Editor Version 5.00\r\n\r\n")
            f.write("[HKEY_CURRENT_USER\\Software\\Future Pinball\\GamePlayer]\r\n")
            f.write(f"\"AspectRatio\"=dword:{FpinballGenerator.getGfxRatioFromConfig(system.config):08x}\r\n")
            f.write("\"FullScreen\"=dword:00000001\r\n")
            f.write(f"\"Width\"=dword:{gameResolution['width']:08x}\r\n")
            f.write(f"\"Height\"=dword:{gameResolution['height']:08x}\r\n")
            f.write("\"JoypadNameNum\"=dword:00000001\r\n")
            f.write("\r\n")

            if system.isOptSet("fpcontroller") and system.config["fpcontroller"] == "True":
                mapping = {
                    "a": "JoypadBackbox",
                    "b": "JoypadDigitalPlunger",
                    "x": "JoypadPause",
                    "y": "JoypadNextCamera",
                    "pageup": "JoypadLeftFlipper",
                    "pagedown": "JoypadRightFlipper",
                    "start": "JoypadStartGame",
                    "select": "JoypadInsertCoin",
                    "r3": "JoypadToggleHud",
                }

                for nplayer, (_playercontroller, pad) in enumerate(sorted(playersControllers.items()), start=1):
                    if nplayer > 1:
                        break
                    joystickname = pad.real_name
                    unassigned_value = int("ffffffff", 16)
                    assigns = {
                        "JoypadBackbox": unassigned_value,
                        "JoypadDigitalPlunger": unassigned_value,
                        "JoypadInsertCoin": unassigned_value,
                        "JoypadNextCamera": unassigned_value,
                        "JoypadLeftFlipper": unassigned_value,
                        "JoypadRightFlipper": unassigned_value,
                        "JoypadPause": unassigned_value,
                        "JoypadStartGame": unassigned_value,
                        "JoypadToggleHud": unassigned_value,
                    }
                    for x in pad.inputs:
                        if x in mapping and mapping[x] in assigns and pad.inputs[x].type == "button":
                            assigns[mapping[x]] = int(pad.inputs[x].id)

                    f.write(f"[HKEY_CURRENT_USER\\Software\\Future Pinball\\GamePlayer\\Joypads\\{joystickname}]\r\n")
                    f.write(f"\"JoypadBackbox\"=dword:{assigns['JoypadBackbox']:08x}\r\n")
                    f.write("\"JoypadDeadZone\"=dword:00000064\r\n")
                    f.write(f"\"JoypadDigitalPlunger\"=dword:{assigns['JoypadDigitalPlunger']:08x}\r\n")
                    f.write("\"JoypadExit\"=dword:ffffffff\r\n")
                    f.write(f"\"JoypadInsertCoin\"=dword:{assigns['JoypadInsertCoin']:08x}\r\n")
                    f.write("\"JoypadInsertCoin2\"=dword:ffffffff\r\n")
                    f.write("\"JoypadInsertCoin3\"=dword:ffffffff\r\n")
                    f.write("\"JoypadLeft2ndFlipper\"=dword:ffffffff\r\n")
                    f.write(f"\"JoypadLeftFlipper\"=dword:{assigns['JoypadLeftFlipper']:08x}\r\n")
                    f.write("\"JoypadMusicDown\"=dword:ffffffff\r\n")
                    f.write("\"JoypadMusicUp\"=dword:ffffffff\r\n")
                    f.write(f"\"JoypadNextCamera\"=dword:{assigns['JoypadNextCamera']:08x}\r\n")
                    f.write("\"JoypadNudgeAxisX\"=dword:ffffffff\r\n")
                    f.write("\"JoypadNudgeAxisY\"=dword:ffffffff\r\n")
                    f.write("\"JoypadNudgeGainX\"=dword:000003e8\r\n")
                    f.write("\"JoypadNudgeGainXMax\"=dword:00000002\r\n")
                    f.write("\"JoypadNudgeGainY\"=dword:000003e8\r\n")
                    f.write("\"JoypadNudgeGainYMax\"=dword:00000002\r\n")
                    f.write(f"\"JoypadPause\"=dword:{assigns['JoypadPause']:08x}\r\n")
                    f.write("\"JoypadPinballRoller\"=dword:ffffffff\r\n")
                    f.write("\"JoypadPinballRollerAxisX\"=dword:ffffffff\r\n")
                    f.write("\"JoypadPinballRollerAxisY\"=dword:ffffffff\r\n")
                    f.write("\"JoypadPinballRollerGainX\"=dword:000003e8\r\n")
                    f.write("\"JoypadPinballRollerGainXMax\"=dword:00000002\r\n")
                    f.write("\"JoypadPinballRollerGainY\"=dword:000003e8\r\n")
                    f.write("\"JoypadPinballRollerGainYMax\"=dword:00000002\r\n")
                    f.write("\"JoypadPlungerAxis\"=dword:00000001\r\n")
                    f.write("\"JoypadPlungerGain\"=dword:000003e8\r\n")
                    f.write("\"JoypadPlungerGainMax\"=dword:00000002\r\n")
                    f.write("\"JoypadRight2ndFlipper\"=dword:ffffffff\r\n")
                    f.write(f"\"JoypadRightFlipper\"=dword:{assigns['JoypadRightFlipper']:08x}\r\n")
                    f.write("\"JoypadService\"=dword:ffffffff\r\n")
                    f.write("\"JoypadSpecial1\"=dword:ffffffff\r\n")
                    f.write("\"JoypadSpecial2\"=dword:ffffffff\r\n")
                    f.write(f"\"JoypadStartGame\"=dword:{assigns['JoypadStartGame']:08x}\r\n")
                    f.write("\"JoypadSupport\"=dword:00000001\r\n")
                    f.write("\"JoypadTest\"=dword:ffffffff\r\n")
                    f.write(f"\"JoypadToggleHud\"=dword:{assigns['JoypadToggleHud']:08x}\r\n")
                    f.write("\"JoypadVolumeDown\"=dword:ffffffff\r\n")
                    f.write("\"JoypadVolumeUp\"=dword:ffffffff\r\n")
                    f.write("\r\n")

        cmd = ["wine", "regedit", _FPINBALL_CONFIG_REG]
        env = {"LD_LIBRARY_PATH": "/lib32:/usr/wine/wine-tkg/lib/wine", "WINEPREFIX": wineprefix}
        env.update(os.environ)
        env["PATH"] = "/usr/wine/wine-tkg/bin:/bin:/usr/bin"
        proc = subprocess.Popen(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = proc.communicate()
        eslog.debug(out.decode())
        eslog.error(err.decode())

        environment = {
            "WINEPREFIX": wineprefix,
            "LD_LIBRARY_PATH": "/lib32:/usr/wine/wine-tkg/lib/wine",
            "LIBGL_DRIVERS_PATH": "/lib32/dri",
            "SPA_PLUGIN_DIR": "/usr/lib/spa-0.2:/lib32/spa-0.2",
            "PIPEWIRE_MODULE_DIR": "/usr/lib/pipewire-0.3:/lib32/pipewire-0.3",
        }
        if Path("/var/tmp/nvidia.prime").exists():
            for variable_name in ["__NV_PRIME_RENDER_OFFLOAD", "__VK_LAYER_NV_optimus", "__GLX_VENDOR_LIBRARY_NAME"]:
                os.environ.pop(variable_name, None)
            environment.update({
                "VK_ICD_FILENAMES": "/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json",
                "VK_LAYER_PATH": "/usr/share/vulkan/explicit_layer.d",
            })

        return Command.Command(array=commandArray, env=environment)

    @staticmethod
    def getGfxRatioFromConfig(config):
        if "ratio" in config:
            if config["ratio"] == "4/3":
                return 43
            if config["ratio"] == "16/9":
                return 169
        return 43
