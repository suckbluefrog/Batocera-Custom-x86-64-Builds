#!/bin/sh

GMUPATH="/userdata/system/configs/gmu"
GMUCONFIG="${GMUPATH}/gmu.conf"
GMUINPUT="${GMUPATH}/gmuinput.conf"
MUSICDIR="/userdata/roms/music"
LOGDIR="/userdata/system/logs"

mkdir -p "${GMUPATH}" "${MUSICDIR}" "${LOGDIR}"

export SDL_AUDIODRIVER="${GMU_SDL_AUDIODRIVER:-alsa}"

has_xbox_controller() {
    grep -Eqi 'Name=.*(Xbox|X-Box|Microsoft Xbox|Microsoft X-Box)' /proc/bus/input/devices 2>/dev/null
}

write_xbox_gmuinput() {
    cat > "${GMUINPUT}" <<'EOF'
FullKeyboard=no
JoyButton-0=0,Ignore
JoyButton-1=1,A
JoyButton-2=2,B
JoyButton-3=4,Y
JoyButton-4=5,X
JoyButton-5=7,L
JoyButton-6=8,R
JoyButton-7=11,Select
JoyButton-8=12,Start
JoyButton-9=13,Menu
JoyButton-10=14,StickClick
JoyButton-11=15,HelpI
JoyButton-12=200,Up
JoyButton-13=201,Down
JoyButton-14=202,Left
JoyButton-15=203,Right
JoyAxis-0=-1,Left
JoyAxis-1=1,Right
JoyAxis-2=-2,Up
JoyAxis-3=2,Down
EOF
}

if [ ! -f "${GMUCONFIG}" ]; then
    cp /usr/share/gmu/batocera/gmu.conf "${GMUCONFIG}"
fi

if has_xbox_controller; then
    write_xbox_gmuinput
else
    cp /usr/share/gmu/batocera/gmuinput.conf "${GMUINPUT}"
fi
sed -i \
    -e "s~^SDL.InputConfigFile=.*~SDL.InputConfigFile=${GMUINPUT}~" \
    -e "s~^SDL.KeyMap=.*~SDL.KeyMap=batocera.keymap~" \
    "${GMUCONFIG}"

resolution="$(batocera-resolution currentResolution 2>/dev/null || true)"
case "${resolution}" in
    *x*)
        width="${resolution%x*}"
        height="${resolution#*x}"
        ;;
    *)
        width=1280
        height=720
        ;;
esac

sed -i \
    -e "s~^SDL.Height=.*~SDL.Height=${height}~" \
    -e "s~^SDL.Width=.*~SDL.Width=${width}~" \
    "${GMUCONFIG}"

if [ "${width}" -le 1024 ]; then
    sed -i \
        -e "s~^SDL.DefaultSkin=.*~SDL.DefaultSkin=default-modern~" \
        -e "s~^SDL.Fullscreen=.*~SDL.Fullscreen=no~" \
        "${GMUCONFIG}"
else
    sed -i \
        -e "s~^SDL.DefaultSkin=.*~SDL.DefaultSkin=default-modern-large~" \
        -e "s~^SDL.Fullscreen=.*~SDL.Fullscreen=yes~" \
        "${GMUCONFIG}"
fi

cd /usr/share/gmu || exit 1

if [ -n "${1:-}" ] && [ -f "$1" ]; then
    exec /usr/bin/gmu.bin -d /usr/etc/gmu -c "${GMUCONFIG}" "$1"
fi

exec /usr/bin/gmu.bin -d /usr/etc/gmu -c "${GMUCONFIG}"
