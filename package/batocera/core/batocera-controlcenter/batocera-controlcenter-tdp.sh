#!/bin/bash

set -euo pipefail

supports_tdp() {
    command -v /usr/bin/batocera-amd-tdp >/dev/null 2>&1 || return 1
    /usr/bin/batocera-amd-tdp --limits >/dev/null 2>&1
}

get_current_tdp() {
    local current requested configured

    current=$(/usr/bin/batocera-amd-tdp --current 2>/dev/null || true)
    if [ -n "${current}" ]; then
        printf "%.0f\n" "${current}"
        return 0
    fi

    current=$(/usr/bin/ryzenadj -i 2>/dev/null | awk '
        /PPT LIMIT FAST/ {
            for (i = 1; i <= NF; i++) {
                gsub(/[|W]/, "", $i)
                if ($i ~ /^[0-9]+(\.[0-9]+)?$/) {
                    printf "%.0f\n", $i
                    exit
                }
            }
        }
    ')
    if [ -n "${current}" ]; then
        printf "%s\n" "${current}"
        return 0
    fi

    requested=$(cat /var/run/amd-tdp.current 2>/dev/null || true)
    if [ -n "${requested}" ]; then
        printf "%.0f\n" "${requested}"
        return 0
    fi

    configured=$(/usr/bin/batocera-settings-get system.cpu.tdp 2>/dev/null || true)
    if [ -n "${configured}" ]; then
        printf "%.0f\n" "${configured}"
    fi
}

get_max_tdp() {
    local limits configured

    limits=$(/usr/bin/batocera-amd-tdp --limits 2>/dev/null || true)
    if [ -n "${limits}" ]; then
        set -- ${limits}
        if [ -n "${2:-}" ]; then
            printf "%.0f\n" "${2}"
            return 0
        fi
    fi

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
