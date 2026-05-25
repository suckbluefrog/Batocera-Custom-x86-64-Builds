from __future__ import annotations

import os
import json
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from collections.abc import MutableMapping

    from ..Emulator import Emulator

_LSFG_LAYER = "VK_LAYER_LS_frame_generation"
_HOME = Path("/userdata/system")
_CONFIG_DIR = _HOME / "configs" / "lsfg-vk"


def _append_colon_value(env: MutableMapping[str, str | Path], key: str, value: str) -> None:
    existing = str(env.get(key, "")).strip()
    values = [item for item in existing.split(":") if item]
    if value not in values:
        values.insert(0, value)
    env[key] = ":".join(values)


def _resolve_lossless_dll(configured_path: str) -> Path | None:
    candidates: list[Path] = []
    if configured_path:
        if configured_path.startswith("~/"):
            candidates.append(_HOME / configured_path[2:])
        else:
            candidates.append(Path(configured_path))

    candidates.extend(
        (
            _HOME / "wine" / "lossless-scaling" / "Lossless.dll",
            _HOME / "wine" / ".local" / "share" / "Steam" / "steamapps" / "common" / "Lossless Scaling" / "Lossless.dll",
            _HOME / ".local" / "share" / "Steam" / "steamapps" / "common" / "Lossless Scaling" / "Lossless.dll",
            Path("/userdata/roms/windows/Lossless Scaling/Lossless.dll"),
        )
    )

    for candidate in candidates:
        if candidate.is_file():
            return candidate

    return None


def _default_performance_mode() -> bool:
    return os.uname().machine.lower() in {"aarch64", "arm64"}


def _default_flow_scale() -> str:
    return "0.75" if os.uname().machine.lower() in {"aarch64", "arm64"} else "1.0"


def _resolve_layer_paths(*, use_wine_layer: bool = False, wine_mode: str = "box64") -> tuple[Path, Path, Path] | None:
    machine = os.uname().machine.lower()
    use_private_x64_layer = use_wine_layer and (
        machine not in {"aarch64", "arm64"} or wine_mode == "fex"
    )

    if use_private_x64_layer:
        root = Path("/usr/wine/lsfg-vk/x64")
        return (
            root,
            root / "lib" / "liblsfg-vk.so",
            root / "share" / "vulkan" / "explicit_layer.d",
        )

    if machine in {"x86_64", "amd64"}:
        root = Path("/usr/wine/lsfg-vk/x64")
        return (
            root,
            root / "lib" / "liblsfg-vk.so",
            root / "share" / "vulkan" / "explicit_layer.d",
        )

    if machine in {"aarch64", "arm64"}:
        root = Path("/usr")
        return (
            root,
            root / "lib" / "liblsfg-vk.so",
            root / "share" / "vulkan" / "explicit_layer.d",
        )

    return None


def _toml_string(value: str | Path) -> str:
    return json.dumps(str(value))


def _toml_bool(value: str) -> str:
    return "true" if value == "1" else "false"


def _toml_uint(value: str, default: str = "2", minimum: int = 1) -> str:
    if value.isdigit() and int(value) >= minimum:
        return value
    return default


def _toml_float(value: str, default: str = "1.0") -> str:
    try:
        parsed = float(value)
    except ValueError:
        return default
    if 0.25 <= parsed <= 1.0:
        formatted = f"{parsed:g}"
        if "." not in formatted and "e" not in formatted.lower():
            formatted += ".0"
        return formatted
    return default


def _write_process_config(
    system: Emulator,
    process_names: list[str],
    dll_path: Path,
    *,
    config_name: str = "batocera",
) -> Path | None:
    names: list[str] = []
    for name in process_names:
        clean = Path(str(name).strip()).name
        if clean and clean not in names:
            names.append(clean)

    if not names:
        return None

    try:
        _CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    except OSError:
        return None

    config_path = _CONFIG_DIR / f"{config_name}.toml"
    multiplier = _toml_uint(system.config.get_str("lsfg_vk_multiplier", "2"), minimum=1)
    flow_scale = _toml_float(system.config.get_str("lsfg_vk_flow_scale", _default_flow_scale()), _default_flow_scale())
    performance = _toml_bool(
        system.config.get_bool("lsfg_vk_performance", _default_performance_mode(), return_values=("1", "0"))
    )
    hdr = _toml_bool(system.config.get_bool("lsfg_vk_hdr", False, return_values=("1", "0")))
    present_mode = system.config.get_str("lsfg_vk_present_mode", "").strip()

    lines = [
        "version = 1",
        "",
        "[global]",
        f"dll = {_toml_string(dll_path)}",
        "",
    ]
    for name in names:
        lines.extend(
            [
                "[[game]]",
                f"exe = {_toml_string(name)}",
                f"multiplier = {multiplier}",
                f"flow_scale = {flow_scale}",
                f"performance_mode = {performance}",
                f"hdr_mode = {hdr}",
            ]
        )
        if present_mode in {"fifo", "vsync", "mailbox", "immediate"}:
            lines.append(f"experimental_present_mode = {_toml_string(present_mode)}")
        lines.append("")

    try:
        config_path.write_text("\n".join(lines), encoding="utf-8")
    except OSError:
        return None

    return config_path


def apply_lsfg_vk(
    system: Emulator,
    env: MutableMapping[str, str | Path],
    *,
    backend_key: str | None = None,
    process_name: str | None = None,
    process_names: list[str] | None = None,
    config_name: str = "batocera",
    use_wine_layer: bool = False,
    defer_layer_env: bool = False,
) -> None:
    wine_mode = system.config.get_str("aarch64_wine_mode", "box64").strip().lower()
    layer_paths = _resolve_layer_paths(use_wine_layer=use_wine_layer, wine_mode=wine_mode)
    if layer_paths is None:
        return

    if not system.config.get_bool("lsfg_vk", False):
        return

    if backend_key and system.config.get_str(backend_key, "1") != "1":
        return

    root, library, layer_dir = layer_paths
    if not library.is_file() or not layer_dir.is_dir():
        return

    dll_path = _resolve_lossless_dll(system.config.get_str("lsfg_vk_dll", "").strip())
    if dll_path is None:
        return

    env["ENABLE_LSFG"] = "1"

    if process_names is not None:
        config_path = _write_process_config(system, process_names, dll_path, config_name=config_name)
        if config_path is None:
            env.pop("ENABLE_LSFG", None)
            return
        env["LSFG_CONFIG"] = str(config_path)
        _append_colon_value(env, "VK_LAYER_PATH", str(layer_dir))
        _append_colon_value(env, "LD_LIBRARY_PATH", str(root / "lib"))
        _append_colon_value(env, "VK_INSTANCE_LAYERS", _LSFG_LAYER)
        return

    env["LSFG_LEGACY"] = "1"
    env["LSFG_DLL_PATH"] = str(dll_path)
    env["LSFG_MULTIPLIER"] = system.config.get_str("lsfg_vk_multiplier", "2")
    env["LSFG_FLOW_SCALE"] = system.config.get_str("lsfg_vk_flow_scale", _default_flow_scale())
    env["LSFG_PERFORMANCE_MODE"] = system.config.get_bool(
        "lsfg_vk_performance", _default_performance_mode(), return_values=("1", "0")
    )
    env["LSFG_HDR_MODE"] = system.config.get_bool("lsfg_vk_hdr", False, return_values=("1", "0"))

    present_mode = system.config.get_str("lsfg_vk_present_mode", "").strip()
    if present_mode in {"fifo", "vsync", "mailbox", "immediate"}:
        env["LSFG_EXPERIMENTAL_PRESENT_MODE"] = present_mode

    if process_name:
        env["LSFG_PROCESS"] = process_name

    if defer_layer_env:
        env["BATOCERA_LSFG_WINE_LAYER"] = "1"
        return

    _append_colon_value(env, "VK_LAYER_PATH", str(layer_dir))
    _append_colon_value(env, "LD_LIBRARY_PATH", str(root / "lib"))
    _append_colon_value(env, "VK_INSTANCE_LAYERS", _LSFG_LAYER)
