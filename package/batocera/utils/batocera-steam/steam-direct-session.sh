#!/bin/bash
set -euo pipefail

LOG="/userdata/system/logs/steam.log"
ES_SERVICE="/etc/init.d/S31emulationstation"

mkdir -p "$(dirname "${LOG}")"

log() {
    echo "steam-direct-session: $*" >> "${LOG}"
}

ensure_runtime_dir() {
    local uid
    local candidate

    uid="$(id -u)"
    candidate="/run/user/${uid}"
    mkdir -p "${candidate}"
    chmod 700 "${candidate}" 2>/dev/null || true
    export XDG_RUNTIME_DIR="${candidate}"
}

parse_resolution() {
    local value="${1:-}"

    if [[ "${value}" =~ ^([0-9]+)x([0-9]+)$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}x${BASH_REMATCH[2]}"
        return 0
    fi

    return 1
}

detect_resolution() {
    local parsed

    parsed="$(parse_resolution "${BATOCERA_STEAM_GS_DEFAULT_RES:-}" || true)"
    if [[ -n "${parsed}" ]]; then
        printf '%s\n' "${parsed}"
        return 0
    fi

    if command -v batocera-resolution >/dev/null 2>&1; then
        parsed="$(parse_resolution "$(batocera-resolution currentResolution 2>/dev/null || true)" || true)"
        if [[ -n "${parsed}" ]]; then
            printf '%s\n' "${parsed}"
            return 0
        fi
    fi

    printf '1280x720\n'
}

detect_refresh_rate() {
    local value

    if [[ "${BATOCERA_STEAM_GS_NESTED_REFRESH:-}" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "${BATOCERA_STEAM_GS_NESTED_REFRESH}"
        return 0
    fi

    if command -v batocera-resolution >/dev/null 2>&1; then
        value="$(batocera-resolution refreshRate 2>/dev/null || true)"
        if [[ "${value}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            awk -v rate="${value}" 'BEGIN { printf "%d\n", int(rate + 0.5) }'
            return 0
        fi
    fi

    printf '60\n'
}

ensure_cef_remote_debugging_markers() {
    local marker

    for marker in \
        "/userdata/system/steam/.cef-enable-remote-debugging" \
        "/userdata/system/.steam/steam/.cef-enable-remote-debugging" \
        "/userdata/system/.local/share/Steam/.cef-enable-remote-debugging"
    do
        mkdir -p "$(dirname "${marker}")"
        touch "${marker}"
    done
}

frontend_running() {
    pgrep -x emulationstation >/dev/null 2>&1 || \
    pgrep -x labwc >/dev/null 2>&1 || \
    pgrep -x sway >/dev/null 2>&1 || \
    pgrep -x openbox >/dev/null 2>&1
}

wait_for_frontend_stop() {
    local i

    for i in $(seq 1 100); do
        if ! frontend_running; then
            return 0
        fi
        sleep 0.1
    done

    return 1
}

restore_frontend() {
    if frontend_running; then
        log "frontend already running after Steam exit"
        return 0
    fi

    if [[ -x "${ES_SERVICE}" ]]; then
        log "starting EmulationStation service after Steam exit"
        "${ES_SERVICE}" start >/dev/null 2>&1 || "${ES_SERVICE}" restart >/dev/null 2>&1 || true
    fi
}

cleanup() {
    local rc=$?

    log "Steam session exited with status ${rc}"
    restore_frontend
    exit "${rc}"
}

trap cleanup EXIT INT TERM

log "requested direct Steam session launch"

if [[ -x "${ES_SERVICE}" ]]; then
    log "stopping EmulationStation frontend before Steam launch"
    "${ES_SERVICE}" stop >/dev/null 2>&1 || true
    if ! wait_for_frontend_stop; then
        log "frontend did not stop cleanly before Steam launch"
    fi
fi

unset DISPLAY
unset WAYLAND_DISPLAY
unset SWAYSOCK
unset XAUTHORITY
unset LABWC_PID
unset WLR_XWAYLAND_NO_AUTH
unset GAMESCOPE_DISPLAY
unset GAMESCOPE_WAYLAND_DISPLAY
unset GAMESCOPE_SESSION
unset DBUS_SESSION_BUS_ADDRESS

ensure_runtime_dir

detected_resolution="$(detect_resolution)"
detected_refresh="$(detect_refresh_rate)"

export BATOCERA_STEAM_MODE="${BATOCERA_STEAM_MODE:-steamos}"
export BATOCERA_STEAM_USE_GAMESCOPE="1"
export BATOCERA_STEAM_GAMEPADUI="${BATOCERA_STEAM_GAMEPADUI:-1}"
export BATOCERA_STEAM_GS_BACKEND="${BATOCERA_STEAM_GS_BACKEND:-drm}"
export BATOCERA_STEAM_GS_DEFAULT_RES="${BATOCERA_STEAM_GS_DEFAULT_RES:-${detected_resolution}}"
export BATOCERA_STEAM_GS_OUTPUT_RES="${BATOCERA_STEAM_GS_OUTPUT_RES:-${BATOCERA_STEAM_GS_DEFAULT_RES}}"
export BATOCERA_STEAM_GS_NESTED_RES="${BATOCERA_STEAM_GS_NESTED_RES:-${BATOCERA_STEAM_GS_DEFAULT_RES}}"
export BATOCERA_STEAM_GS_NESTED_REFRESH="${BATOCERA_STEAM_GS_NESTED_REFRESH:-${detected_refresh}}"
export BATOCERA_STEAM_GS_DISABLE_HW_COMPOSITION="${BATOCERA_STEAM_GS_DISABLE_HW_COMPOSITION:-1}"
export BATOCERA_STEAM_GS_FORCE_COMPOSITION_PIPELINE="${BATOCERA_STEAM_GS_FORCE_COMPOSITION_PIPELINE:-1}"
export BATOCERA_STEAM_GS_SCALER="${BATOCERA_STEAM_GS_SCALER:-stretch}"
export BATOCERA_STEAM_GS_FILTER="${BATOCERA_STEAM_GS_FILTER:-linear}"

log "using gamescope defaults res=${BATOCERA_STEAM_GS_DEFAULT_RES} output=${BATOCERA_STEAM_GS_OUTPUT_RES} nested=${BATOCERA_STEAM_GS_NESTED_RES} refresh=${BATOCERA_STEAM_GS_NESTED_REFRESH}"

ensure_cef_remote_debugging_markers

steam_args=()
case "${1:-}" in
    gameStart|gameStop|systemSelected|systemDeselected)
        log "ignoring Batocera launcher hook arguments: $*"
        ;;
    "")
        ;;
    *)
        steam_args=("$@")
        ;;
esac

log "launching batocera-steam with mode=${BATOCERA_STEAM_MODE} args=${steam_args[*]:-<none>}"
if command -v dbus-run-session >/dev/null 2>&1; then
    dbus-run-session -- /usr/bin/batocera-steam "${steam_args[@]}"
else
    /usr/bin/batocera-steam "${steam_args[@]}"
fi
