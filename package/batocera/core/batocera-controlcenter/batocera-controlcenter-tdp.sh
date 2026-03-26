#!/bin/bash

set -euo pipefail

supports_tdp() {
    command -v /usr/bin/ryzenadj >/dev/null 2>&1 || return 1
    /usr/bin/ryzenadj -i 2>/dev/null | head -n 1 | grep -q "unsupported model" && return 1
    return 0
}

get_current_tdp() {
    local current configured

    current=$(/usr/bin/ryzenadj -i 2>/dev/null | awk '
        /PPT LIMIT FAST/ {
            if (match($0, /([0-9]+(\.[0-9]+)?)W/, m)) {
                printf "%.0f\n", m[1]
                exit
            }
        }
    ')
    if [ -n "${current}" ]; then
        printf "%s\n" "${current}"
        return 0
    fi

    configured=$(/usr/bin/batocera-settings-get system.cpu.tdp 2>/dev/null || true)
    if [ -n "${configured}" ]; then
        printf "%.0f\n" "${configured}"
    fi
}

get_max_tdp() {
    local configured
    configured=$(/usr/bin/batocera-settings-get system.cpu.tdp 2>/dev/null || true)
    if [ -n "${configured}" ]; then
        printf "%.0f\n" "${configured}"
        return 0
    fi

    get_current_tdp
}

case "${1:-}" in
    supported)
        supports_tdp && echo 1 || true
        ;;
    current)
        supports_tdp || exit 0
        current=$(get_current_tdp)
        [ -n "${current}" ] && echo "${current}W"
        ;;
    max)
        supports_tdp || exit 0
        max=$(get_max_tdp)
        [ -n "${max}" ] && echo "${max}W"
        ;;
    summary)
        supports_tdp || exit 0
        current=$(get_current_tdp)
        max=$(get_max_tdp)
        if [ -n "${current}" ] && [ -n "${max}" ]; then
            echo "${current}W / ${max}W"
        elif [ -n "${max}" ]; then
            echo "-- / ${max}W"
        elif [ -n "${current}" ]; then
            echo "${current}W"
        fi
        ;;
    set)
        supports_tdp || exit 1
        [ -n "${2:-}" ] || exit 1
        /usr/bin/batocera-amd-tdp "${2}"
        ;;
    inc)
        supports_tdp || exit 1
        current=$(get_current_tdp)
        [ -n "${current}" ] || exit 1
        /usr/bin/batocera-amd-tdp "$((current + 1))"
        ;;
    dec)
        supports_tdp || exit 1
        current=$(get_current_tdp)
        [ -n "${current}" ] || exit 1
        /usr/bin/batocera-amd-tdp "$((current - 1))"
        ;;
    *)
        echo "Usage: $0 {supported|current|max|summary|set <watts>|inc|dec}" >&2
        exit 1
        ;;
esac
