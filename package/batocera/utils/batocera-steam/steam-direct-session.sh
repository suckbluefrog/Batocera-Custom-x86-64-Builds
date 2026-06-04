#!/bin/bash
set -euo pipefail

LOG="/userdata/system/logs/steam.log"
ES_SERVICE="/etc/init.d/S31emulationstation"
export BATOCERA_STEAM_ROOT="${BATOCERA_STEAM_ROOT:-/userdata/system/steam}"

mkdir -p "$(dirname "${LOG}")"

log() {
    echo "steam-direct-session: $*" >> "${LOG}"
}

UPDATE_TERMINAL_DISPLAY="${DISPLAY:-}"
UPDATE_TERMINAL_WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}"
UPDATE_TERMINAL_XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}"
UPDATE_TERMINAL_XAUTHORITY="${XAUTHORITY:-}"
UPDATE_TERMINAL_DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}"

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

clear_frontend_restore_env() {
    local name

    for name in "${!BATOCERA_STEAM_@}"; do
        unset "${name}"
    done
    for name in "${!GAMESCOPE_@}"; do
        unset "${name}"
    done

    unset STEAM_DECK
    unset STEAMOS
    unset STEAM_GAMEPADUI
    unset STEAM_FORCE_DESKTOPUI
    unset STEAM_GAME
    unset SteamGameId
    unset SteamAppId
    unset STEAM_USE_MANGOAPP
    unset STEAM_MANGOAPP_PRESETS_SUPPORTED
    unset GAMESCOPE_DISPLAY
    unset GAMESCOPE_WAYLAND_DISPLAY
    unset GAMESCOPE_SESSION
    unset WLR_DRM_DEVICES
    unset WLR_LIBINPUT_NO_DEVICES
    unset SDL_NOMOUSE
}

restore_frontend() {
    if frontend_running; then
        log "frontend already running after Steam exit"
        return 0
    fi

    if [[ -x "${ES_SERVICE}" ]]; then
        log "starting EmulationStation service after Steam exit"
        clear_frontend_restore_env
        "${ES_SERVICE}" start >/dev/null 2>&1 || "${ES_SERVICE}" restart >/dev/null 2>&1 || true
    fi
}

start_session_supervisor() {
    [[ "${BATOCERA_STEAM_SESSION_SUPERVISOR:-0}" == "1" ]] || return 0
    command -v batocera-steam-session-supervisor >/dev/null 2>&1 || return 0
    batocera-steam-session-supervisor start "steam-direct-session" >/dev/null 2>&1 || true
}

recover_frontend_with_supervisor() {
    [[ "${BATOCERA_STEAM_SESSION_SUPERVISOR:-0}" == "1" ]] || return 0
    command -v batocera-steam-session-supervisor >/dev/null 2>&1 || return 0
    batocera-steam-session-supervisor recover "direct-cleanup" >/dev/null 2>&1 || true
}

run_visible_update_preflight() {
    [[ "${BATOCERA_STEAM_VISIBLE_UPDATE_PREFLIGHT:-0}" != "0" ]] || return 0
    [[ -x /usr/bin/batocera-steam-update-preflight ]] || return 0

    log "running visible Steam updater preflight before Gamescope"
    if /usr/bin/batocera-steam-update-preflight launch >> "${LOG}" 2>&1; then
        log "visible Steam updater preflight completed"
    else
        log "visible Steam updater preflight failed; continuing to Gamescope"
    fi
}

cleanup() {
    local rc=$?

    log "Steam session exited with status ${rc}"
    restore_frontend
    recover_frontend_with_supervisor
    exit "${rc}"
}

trap cleanup EXIT INT TERM

log "requested direct Steam session launch"

run_visible_update_preflight

if [[ -x "${ES_SERVICE}" ]]; then
    log "stopping EmulationStation frontend before Steam launch"
    "${ES_SERVICE}" stop >/dev/null 2>&1 || true
    if ! wait_for_frontend_stop; then
        log "frontend did not stop cleanly before Steam launch"
    fi
fi

start_session_supervisor

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

if [[ -n "${UPDATE_TERMINAL_DISPLAY}" ]]; then
    export BATOCERA_STEAM_UPDATE_DISPLAY="${UPDATE_TERMINAL_DISPLAY}"
fi
if [[ -n "${UPDATE_TERMINAL_WAYLAND_DISPLAY}" ]]; then
    export BATOCERA_STEAM_UPDATE_WAYLAND_DISPLAY="${UPDATE_TERMINAL_WAYLAND_DISPLAY}"
fi
if [[ -n "${UPDATE_TERMINAL_XDG_RUNTIME_DIR}" ]]; then
    export BATOCERA_STEAM_UPDATE_XDG_RUNTIME_DIR="${UPDATE_TERMINAL_XDG_RUNTIME_DIR}"
fi
if [[ -n "${UPDATE_TERMINAL_XAUTHORITY}" ]]; then
    export BATOCERA_STEAM_UPDATE_XAUTHORITY="${UPDATE_TERMINAL_XAUTHORITY}"
fi
if [[ -n "${UPDATE_TERMINAL_DBUS_SESSION_BUS_ADDRESS}" ]]; then
    export BATOCERA_STEAM_UPDATE_DBUS_SESSION_BUS_ADDRESS="${UPDATE_TERMINAL_DBUS_SESSION_BUS_ADDRESS}"
fi

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
export BATOCERA_STEAM_GS_DISABLE_HW_COMPOSITION="${BATOCERA_STEAM_GS_DISABLE_HW_COMPOSITION:-0}"
export BATOCERA_STEAM_GS_FORCE_COMPOSITION_PIPELINE="${BATOCERA_STEAM_GS_FORCE_COMPOSITION_PIPELINE:-0}"
export BATOCERA_STEAM_GS_SCALER="${BATOCERA_STEAM_GS_SCALER:-stretch}"
export BATOCERA_STEAM_GS_FILTER="${BATOCERA_STEAM_GS_FILTER:-linear}"
if [[ "${BATOCERA_STEAM_FORCE_DISABLE_MANGOAPP:-0}" != "1" ]]; then
    export BATOCERA_STEAM_GS_MANGOAPP="${BATOCERA_STEAM_GS_MANGOAPP:-1}"
fi
export BATOCERA_STEAM_MANGOAPP_COLOR_WORKAROUND="${BATOCERA_STEAM_MANGOAPP_COLOR_WORKAROUND:-0}"

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
