#!/bin/bash

if [ -z "${DISPLAY}" ]; then
    export DISPLAY="$(getLocalXDisplay)"
fi

unclutter-remote -s >/dev/null 2>&1 || true

if ! command -v "batocera-config-retroarch" >/dev/null 2>&1; then
    echo "batocera-config-retroarch is not available on this build."
    exit 1
fi

exec batocera-config-retroarch
