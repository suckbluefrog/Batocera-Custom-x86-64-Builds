#!/bin/sh

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/var/run}"
export SWAYSOCK=/var/run/sway-ipc.0.sock
