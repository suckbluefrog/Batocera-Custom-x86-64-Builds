#!/bin/sh

# SWAYSOCK=<XDG_RUNTIME_DIR>/sway-ipc.<uid>.sock
export SWAYSOCK="${SWAYSOCK:-${XDG_RUNTIME_DIR}/sway-ipc.0.sock}"
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    WAYLAND_DISPLAY="$(getLocalWaylandDisplay)"
    [ -n "${WAYLAND_DISPLAY}" ] && export WAYLAND_DISPLAY
fi
