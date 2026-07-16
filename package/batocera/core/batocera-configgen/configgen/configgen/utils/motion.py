from __future__ import annotations

import os
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from ..controller import Controllers
    from .configparser import CaseSensitiveRawConfigParser


DSU_HOST = "127.0.0.1"
DSU_DEFAULT_PORT = 26760
DSU_SWITCH_GUID = "00000000-0000-0000-0000-00007f000001"

_DSU_RUNTIME_FILES = (
    (
        Path("/var/run/batocera-motion.ready"),
        Path("/var/run/batocera-motion.pid"),
    ),
    (
        Path("/var/run/batocera-qcom-motion.ready"),
        Path("/var/run/batocera-qcom-motion.pid"),
    ),
)
_UDP_SOCKET_TABLES = (Path("/proc/net/udp"), Path("/proc/net/udp6"))


def _valid_port(port: int) -> bool:
    return 1 <= port <= 65535


def _server_from_environment() -> tuple[str, int] | None:
    value = os.environ.get("BATOCERA_DSU_SERVER", "").strip()
    if not value:
        return None

    host, separator, port_value = value.rpartition(":")
    if not separator:
        host = value
        port = DSU_DEFAULT_PORT
    else:
        try:
            port = int(port_value)
        except ValueError:
            return None

    if not host or not _valid_port(port):
        return None
    return host, port


def _server_from_runtime_files(
    ready_file: Path,
    pid_file: Path,
) -> tuple[str, int] | None:
    try:
        pid = int(pid_file.read_text().strip())
        os.kill(pid, 0)
        port = int(ready_file.read_text().strip())
    except (OSError, ValueError):
        return None

    if not _valid_port(port):
        return None
    return DSU_HOST, port


def _local_udp_port_is_bound(port: int) -> bool:
    port_hex = f"{port:04X}"
    for socket_table in _UDP_SOCKET_TABLES:
        try:
            lines = socket_table.read_text().splitlines()[1:]
        except OSError:
            continue

        for line in lines:
            fields = line.split()
            if len(fields) < 2:
                continue
            local_address = fields[1]
            if local_address.rpartition(":")[2].upper() == port_hex:
                return True
    return False


def get_dsu_server() -> tuple[str, int] | None:
    """Return an active DSU/CemuHook endpoint exposed by the local system."""
    if server := _server_from_environment():
        return server

    for ready_file, pid_file in _DSU_RUNTIME_FILES:
        if server := _server_from_runtime_files(ready_file, pid_file):
            return server

    # SteamDeckGyroDSU and generic IIO-to-DSU bridges normally listen on the
    # standard port but do not publish Batocera runtime files.
    if _local_udp_port_is_bound(DSU_DEFAULT_PORT):
        return DSU_HOST, DSU_DEFAULT_PORT

    return None


def configure_switch_motion(
    parser: CaseSensitiveRawConfigParser,
    players_controllers: Controllers,
) -> None:
    """Configure native SDL sensors and override player one with DSU if present."""
    if not parser.has_section("Controls"):
        parser.add_section("Controls")

    guid_port: dict[str, int] = {}
    configured = False
    for nplayer, pad in enumerate(players_controllers[:10]):
        port = guid_port.get(pad.guid, -1) + 1
        guid_port[pad.guid] = port
        binding = f"engine:sdl,motion:0,port:{port},guid:{pad.guid}"
        for motion in ("motionleft", "motionright"):
            parser.set("Controls", rf"player_{nplayer}_{motion}", f'"{binding}"')
            parser.set("Controls", rf"player_{nplayer}_{motion}\default", "false")
        configured = True

    if server := get_dsu_server():
        host, port = server
        binding = (
            f"engine:cemuhookudp,guid:{DSU_SWITCH_GUID},"
            f"port:{port},pad:0,motion:0"
        )
        parser.set("Controls", "udp_input_servers", f"{host}:{port}")
        parser.set("Controls", r"udp_input_servers\default", "false")
        for motion in ("motionleft", "motionright"):
            parser.set("Controls", rf"player_0_{motion}", f'"{binding}"')
            parser.set("Controls", rf"player_0_{motion}\default", "false")
        configured = True

    if configured:
        parser.set("Controls", "motion_enabled", "true")
        parser.set("Controls", r"motion_enabled\default", "false")
