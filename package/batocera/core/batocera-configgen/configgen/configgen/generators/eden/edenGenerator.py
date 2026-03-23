from __future__ import annotations

import logging
import os
import stat
from pathlib import Path
from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import mkdir_if_not_exists, ensure_parents_and_open
from ...utils import vulkan
from ...utils.configparser import CaseSensitiveRawConfigParser
from ..Generator import Generator

if TYPE_CHECKING:
    from ...Emulator import Emulator

_logger = logging.getLogger(__name__)

# Eden AppImage uses standard XDG paths under HOME
HOME = Path("/userdata/system")
EDEN_CONFIG = HOME / ".config" / "eden"
EDEN_DATA = HOME / ".local/share" / "eden"
EDEN_CACHE = HOME / ".cache" / "eden"

# UCLAMP values (out of 1024)
# 819 = ~80% utilization floor, forces scheduler to use big cores
UCLAMP_MIN = 819
UCLAMP_MAX = 1024


class EdenGenerator(Generator):

    def getHotkeysContext(self):
        return {
            "name": "eden",
            "keys": {"exit": ["KEY_LEFTALT", "KEY_F4"]}
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):

        # ---- Create directory structure ----
        mkdir_if_not_exists(EDEN_CONFIG)
        mkdir_if_not_exists(EDEN_DATA)
        mkdir_if_not_exists(EDEN_DATA / "keys")
        mkdir_if_not_exists(EDEN_DATA / "nand")
        mkdir_if_not_exists(EDEN_DATA / "nand" / "system")
        mkdir_if_not_exists(EDEN_DATA / "nand" / "user")
        mkdir_if_not_exists(EDEN_DATA / "load")
        mkdir_if_not_exists(EDEN_DATA / "sdmc")
        mkdir_if_not_exists(EDEN_CACHE)

        # ---- Write configuration ----
        EdenGenerator.writeConfig(
            EDEN_CONFIG / "qt-config.ini",
            system
        )

        # ---- Build environment ----
        home = str(HOME)
        env = {
            "HOME": home,
            "USER": "root",
            "LOGNAME": "root",
            "PWD": "/userdata",
            "SHELL": "/bin/sh",
            "TERM": "linux",
            "DISPLAY": ":0",
            "WAYLAND_DISPLAY": "wayland-0",
            "XDG_RUNTIME_DIR": "/var/run",
            "XDG_CONFIG_HOME": f"{home}/.config",
            "XDG_DATA_HOME": f"{home}/.local/share",
            "XDG_CACHE_HOME": f"{home}/.cache",
            "LANG": "en_US.UTF-8",
            "LC_ALL": "en_US.UTF-8",
        }

        # ---- UCLAMP performance tuning for big.LITTLE ----
        use_uclamp = system.config.get_bool("perf_uclamp", True)
        uclamp_min = system.config.get_int("perf_uclamp_min", UCLAMP_MIN)

        if use_uclamp:
            wrapper_path = EDEN_CONFIG / "eden-perf.sh"
            EdenGenerator._write_uclamp_wrapper(
                wrapper_path, "/usr/bin/eden", uclamp_min, UCLAMP_MAX
            )
            command_array = [str(wrapper_path), "-f", "-g", str(rom)]
        else:
            command_array = ["/usr/bin/eden", "-f", "-g", str(rom)]

        return Command.Command(
            array=command_array,
            env=env
        )

    @staticmethod
    def _write_uclamp_wrapper(wrapper_path: Path, executable: str, uclamp_min: int, uclamp_max: int):
        """
        Creates a wrapper script that launches the emulator and sets UCLAMP values
        to pin it to big cores on big.LITTLE systems (e.g., SM8550).
        """
        script_content = f'''#!/bin/bash
# Auto-generated UCLAMP performance wrapper for Eden
# Forces scheduler to prefer big cores on big.LITTLE SoCs

EXEC="{executable}"
UCLAMP_MIN={uclamp_min}
UCLAMP_MAX={uclamp_max}

# Launch emulator in background
"$EXEC" "$@" &
EMU_PID=$!

# Brief delay for process to initialize
sleep 0.2

# Apply UCLAMP settings to main process and all threads
apply_uclamp() {{
    local pid=$1
    if [ -d "/proc/$pid" ]; then
        # Main process
        echo $UCLAMP_MIN > /proc/$pid/sched_util_min 2>/dev/null
        echo $UCLAMP_MAX > /proc/$pid/sched_util_max 2>/dev/null
        
        # All threads
        for tid in /proc/$pid/task/*/; do
            tid=$(basename "$tid")
            echo $UCLAMP_MIN > /proc/$pid/task/$tid/sched_util_min 2>/dev/null
            echo $UCLAMP_MAX > /proc/$pid/task/$tid/sched_util_max 2>/dev/null
        done
    fi
}}

# Initial application
apply_uclamp $EMU_PID

# Background task to apply UCLAMP to new threads periodically
(
    while kill -0 $EMU_PID 2>/dev/null; do
        sleep 2
        apply_uclamp $EMU_PID
    done
) &
MONITOR_PID=$!

# Wait for emulator to exit
wait $EMU_PID
EXIT_CODE=$?

# Cleanup monitor
kill $MONITOR_PID 2>/dev/null

exit $EXIT_CODE
'''
        with open(wrapper_path, 'w') as f:
            f.write(script_content)
        
        os.chmod(wrapper_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)

    @staticmethod
    def writeConfig(cfg: Path, system: Emulator):

        c = CaseSensitiveRawConfigParser()
        if cfg.exists():
            c.read(cfg)

        # ---------- UI ----------
        if not c.has_section("UI"):
            c.add_section("UI")

        c.set("UI", "fullscreen", "true")
        c.set("UI", "singleWindowMode", system.config.get("eden_single_window", "true"))
        c.set("UI", "enable_discord_presence", "false")
        c.set("UI", "confirmClose", "false")
        c.set("UI", "UIGameList\\cache_game_list", "false")

        c.set("UI", "Paths\\gamedirs\\1\\path", "/userdata/roms/switch")
        c.set("UI", "Paths\\gamedirs\\size", "1")

        # ---------- Data Storage ----------
        if not c.has_section("Data%20Storage"):
            c.add_section("Data%20Storage")

        c.set("Data%20Storage", "nand_directory", str(EDEN_DATA / "nand"))
        c.set("Data%20Storage", "load_directory", str(EDEN_DATA / "load"))
        c.set("Data%20Storage", "sdmc_directory", str(EDEN_DATA / "sdmc"))
        c.set("Data%20Storage", "use_virtual_sd", "true")

        # ---------- Core ----------
        if not c.has_section("Core"):
            c.add_section("Core")

        # Multicore CPU emulation
        c.set("Core", "use_multi_core", system.config.get("eden_multicore", "true"))
        
        # Memory size (RAM)
        c.set("Core", "memory_layout_mode", system.config.get("eden_memory", "0"))

        # ---------- Renderer ----------
        if not c.has_section("Renderer"):
            c.add_section("Renderer")

        # Backend: 0 = OpenGL GLSL, 1 = Vulkan, 3 = OpenGL GLASM, 4 = OpenGL SPIR-V
        backend = system.config.get("eden_backend", "1")
        c.set("Renderer", "backend", backend)

        if backend == "1" and vulkan.is_available():
            if vulkan.has_discrete_gpu():
                idx = vulkan.get_discrete_gpu_index()
                if idx is not None:
                    c.set("Renderer", "vulkan_device", str(idx))

        # Async GPU emulation
        c.set("Renderer", "use_asynchronous_gpu_emulation",
              system.config.get("eden_async_gpu", "true"))
        
        # Async shaders
        c.set("Renderer", "use_asynchronous_shaders",
              system.config.get("eden_async_shaders", "true"))
        
        # NVDEC emulation
        c.set("Renderer", "nvdec_emulation",
              system.config.get("eden_nvdec_emu", "2"))
        
        # GPU accuracy
        c.set("Renderer", "gpu_accuracy",
              system.config.get("eden_accuracy", "1"))
        
        # Internal resolution scale
        c.set("Renderer", "resolution_setup",
              system.config.get("eden_scale", "3"))
        
        # ASTC texture decoding/recompression
        c.set("Renderer", "astc_recompression",
              system.config.get("eden_astc", "0"))
        
        # VSync
        c.set("Renderer", "use_vsync",
              system.config.get("eden_vsync", "2"))
        
        # Aspect ratio
        c.set("Renderer", "aspect_ratio",
              system.config.get("eden_ratio", "0"))
        
        # Anti-aliasing
        c.set("Renderer", "anti_aliasing",
              system.config.get("eden_anti_aliasing", "0"))
        
        # Scaling filter
        c.set("Renderer", "scaling_filter",
              system.config.get("eden_scaling_filter", "1"))
        
        # Anisotropic filtering
        c.set("Renderer", "max_anisotropy",
              system.config.get("eden_anisotropy", "1"))

        # ---------- CPU ----------
        if not c.has_section("Cpu"):
            c.add_section("Cpu")

        c.set("Cpu", "cpu_accuracy",
              system.config.get("eden_cpuaccuracy", "0"))

        # ---------- System ----------
        if not c.has_section("System"):
            c.add_section("System")

        c.set("System", "language_index",
              system.config.get("eden_language", "1"))
        c.set("System", "region_index",
              system.config.get("eden_region", "1"))
        
        # Docked mode (true = docked, false = handheld)
        c.set("System", "use_docked_mode",
              system.config.get("eden_dock_mode", "true"))

        # ---------- Audio ----------
        if not c.has_section("Audio"):
            c.add_section("Audio")

        # Audio backend
        c.set("Audio", "output_engine",
              system.config.get("eden_audio_backend", "auto"))
        
        # Audio channels (sound_index)
        c.set("Audio", "sound_index",
              system.config.get("eden_sound_index", "1"))

        # ---------- Telemetry ----------
        if not c.has_section("WebService"):
            c.add_section("WebService")

        c.set("WebService", "enable_telemetry", "false")

        with ensure_parents_and_open(cfg, "w") as f:
            c.write(f)
