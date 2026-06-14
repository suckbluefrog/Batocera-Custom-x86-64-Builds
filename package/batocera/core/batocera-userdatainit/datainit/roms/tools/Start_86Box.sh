#!/bin/bash

if test -z "${DISPLAY}"
then
    export DISPLAY=$(getLocalXDisplay)
fi

emulatorlauncher -system 86box -rom config -emulator 86box -core 86box
