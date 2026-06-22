#!/bin/bash

#
# This file is part of the batocera distribution (https://batocera.org).
# Copyright (c) 2025+.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# YOU MUST KEEP THIS HEADER AS IT IS
#

# this configgen script leverages the S93amdtdp init.d and
# the batocera-amd-tdp scripts to allow adjustments to TDP
# of supported AMD CPUs. this can improve performance
# but also improve battery life.
#
# users can set a higher or lower manufacturer TDP accordingly.

log="/userdata/system/logs/amd-tdp.log"
STATE_FILE="/var/run/amd-tdp.changed"
TDP_LIMIT_HELPER="/usr/bin/batocera-tdp-limit"
TDP_LIMIT_FPS_DIR="/var/run/batocera-tdp-limit/fps"
TDP_LIMIT_GAMESCOPE_STATS="/var/run/batocera-tdp-limit/gamescope-stats.pipe"
TDP_LAST_VALUE=""

get_tdp_limit_field() {
    local field=$1
    local limits

    limits=$(/usr/bin/batocera-amd-tdp --limits 2>/dev/null || true)
    [ -n "${limits}" ] || return 1

    set -- ${limits}
    case "${field}" in
        1) [ -n "${1:-}" ] && printf "%.0f\n" "${1}" ;;
        2) [ -n "${2:-}" ] && printf "%.0f\n" "${2}" ;;
        3) [ -n "${3:-}" ] && printf "%.0f\n" "${3}" ;;
        *) return 1 ;;
    esac
}

get_max_tdp() {
    local max configured

    max=$(get_tdp_limit_field 2 2>/dev/null || true)
    if [ -n "${max}" ]; then
        printf "%s\n" "${max}"
        return 0
    fi

    configured=$(/usr/bin/batocera-settings-get system.cpu.tdp 2>/dev/null || true)
    if [ -n "${configured}" ]; then
        printf "%.0f\n" "${configured}"
    fi
}

get_default_tdp() {
    local default

    default=$(get_tdp_limit_field 3 2>/dev/null || true)
    if [ -n "${default}" ]; then
        printf "%s\n" "${default}"
        return 0
    fi

    get_max_tdp
}

# Check we have a max system TDP value
CPU_TDP=$(get_max_tdp)

# If not, we exit as the CPU is not supported by the TDP values
if [ -z "$CPU_TDP" ]; then
    echo "No CPU TDP value found."
    exit 0
fi

# Set the final tdp value
set_tdp() {
    local TDP_VALUE=$1
    local ROM_NAME=$2

    echo "Game ${ROM_NAME} requested setting AMD Processor TDP to ${TDP_VALUE} Watts" >> $log

    /usr/bin/batocera-amd-tdp "$TDP_VALUE"
}

get_launch_setting() {
    local setting=$1
    local value=""

    if [ -n "${SYSTEM_NAME}" ]; then
        value=$(/usr/bin/batocera-settings-get "${SYSTEM_NAME}[\"${ROM_NAME}\"].${setting}" 2>/dev/null || true)
        [ -z "$value" ] && value=$(/usr/bin/batocera-settings-get "${SYSTEM_NAME}.${setting}" 2>/dev/null || true)
    fi

    [ -z "$value" ] && value=$(/usr/bin/batocera-settings-get "global.${setting}" 2>/dev/null || true)
    printf "%s" "$value"
}

start_tdp_limit() {
    local BASE_TDP=$1
    local MODE TARGET MIN_TDP MAX_TDP FPS_SOURCE

    [ -x "$TDP_LIMIT_HELPER" ] || return 0
    "$TDP_LIMIT_HELPER" available >/dev/null 2>&1 || return 0

    MODE=$(get_launch_setting "tdp_mode")
    TARGET=$(get_launch_setting "tdp_target_fps")
    MIN_TDP=$(get_launch_setting "tdp_min")
    MAX_TDP=$(get_launch_setting "tdp_max")

    if [ "$SYSTEM_NAME" = "steam" ]; then
        FPS_SOURCE="$TDP_LIMIT_GAMESCOPE_STATS"
    else
        FPS_SOURCE="$TDP_LIMIT_FPS_DIR"
    fi

    "$TDP_LIMIT_HELPER" game-start "${BASE_TDP:-auto}" "$FPS_SOURCE" "${TARGET:-auto}" "${MODE:-auto}" "${MIN_TDP:-auto}" "${MAX_TDP:-auto}" >/dev/null 2>&1 || true
}

stop_tdp_limit() {
    [ -x "$TDP_LIMIT_HELPER" ] || return 0
    "$TDP_LIMIT_HELPER" game-stop >/dev/null 2>&1 || true
}

# Determine the new TDP value based on max TDP
handle_tdp() {
    local TDP_PERCENTAGE=$1
    local ROM_NAME=$2

    local MAX_TDP
    MAX_TDP=$(get_max_tdp)

    # Check if TDP is defined and non-empty
    if [ -z "$MAX_TDP" ]; then
        echo "A maximum TDP is not defined, cannot set TDP." >> $log
        exit 1
    fi

    # Round the value up or down to make bash happy
    local TDP_VALUE
    TDP_VALUE=$(awk -v max_tdp="$MAX_TDP" -v tdp_percentage="$TDP_PERCENTAGE" 'BEGIN { printf("%.0f\n", max_tdp * tdp_percentage / 100) }')
    TDP_LAST_VALUE="${TDP_VALUE}"
    set_tdp "${TDP_VALUE}" "${ROM_NAME}"
}

do_game_start() {
    local SYSTEM_NAME="$1"
    local ROM_NAME="$2"
    local TDP_SETTING=""
    local RAW_GLOBAL=""
    local BASE_TDP=""

    # Clear previous state file if present
    rm -f "$STATE_FILE" 2>/dev/null

    # Check for user set rom or system specific setting
    if [ -n "${SYSTEM_NAME}" ]; then
        TDP_SETTING=$(/usr/bin/batocera-settings-get "${SYSTEM_NAME}[\"${ROM_NAME}\"].tdp")
        [ -z "$TDP_SETTING" ] && TDP_SETTING=$(/usr/bin/batocera-settings-get "${SYSTEM_NAME}.tdp")
    fi

    # If no user set system specific setting check for user set global setting
    if [ -z "${TDP_SETTING}" ]; then
        RAW_GLOBAL=$(/usr/bin/batocera-settings-get global.tdp)
        if [ -n "${RAW_GLOBAL}" ]; then
            TDP_SETTING=$(printf "%.0f" "${RAW_GLOBAL}")
        fi
    fi

    # Now apply TDP percentage accordingly
    if [ -n "${TDP_SETTING}" ]; then
        handle_tdp "${TDP_SETTING}" "${ROM_NAME}"
        BASE_TDP="${TDP_LAST_VALUE}"
        : > "$STATE_FILE"
    else
        echo "Game START, but no TDP setting defined. Leaving TDP unchanged." >> $log
        echo "" >> "$log"
        echo "*** ------------------------------------- ***" >> "$log"
        echo "" >> "$log"
    fi

    start_tdp_limit "${BASE_TDP:-auto}"
}

do_game_stop() {
    stop_tdp_limit

    # Check if we actually changed anything on game start
    if [ ! -e "$STATE_FILE" ]; then
        echo "Game STOP, but no prior TDP change. Nothing to do." >> "$log"
        echo "" >> "$log"
        echo "*** ------------------------------------- ***" >> "$log"
        echo "" >> "$log"
        exit 0
    fi

    local RAW_GLOBAL
    RAW_GLOBAL=$(/usr/bin/batocera-settings-get global.tdp)

    if [ -n "${RAW_GLOBAL}" ]; then
        TDP_SETTING=$(printf "%.0f" "${RAW_GLOBAL}")
        handle_tdp "$TDP_SETTING" "STOP"
    else
        local SYSTEM_TDP
        SYSTEM_TDP=$(get_default_tdp)
        if [ -n "$SYSTEM_TDP" ]; then
            set_tdp "$SYSTEM_TDP" "STOP"
        else
            echo "No default TDP setting defined, cannot set TDP on game stop." >> $log
            exit 1
        fi
    fi

    rm -f "$STATE_FILE" 2>/dev/null
    exit 0
}

# Check for events
SYSTEM_NAME="$2"
ROM_PATH="$5"

# Get the rom name from ROM_PATH
ROM_NAME=$(basename "$ROM_PATH")

case "$1" in
    gameStart)
        do_game_start "$SYSTEM_NAME" "$ROM_NAME"
        ;;
    gameStop)
        do_game_stop
        ;;
    *)
        exit 0
        ;;
esac

exit 0
