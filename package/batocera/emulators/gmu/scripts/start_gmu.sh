#!/bin/sh

GMUPATH="/userdata/system/configs/gmu"
GMUCONFIG="${GMUPATH}/gmu.conf"
GMUINPUT="${GMUPATH}/gmuinput.conf"
MUSICDIR="/userdata/roms/music"
LOGDIR="/userdata/system/logs"

mkdir -p "${GMUPATH}" "${MUSICDIR}" "${LOGDIR}"

export SDL_AUDIODRIVER="${GMU_SDL_AUDIODRIVER:-alsa}"

mapping_value() {
    local key="${1}"

    printf '%s\n' "${SDL_GAMECONTROLLERCONFIG:-}" | tr ',' '\n' | sed -n "s/^${key}://p" | head -n 1
}

button_value() {
    local key="${1}"
    local fallback="${2}"
    local value

    value="$(mapping_value "${key}")"
    case "${value}" in
        b[0-9]*)
            printf '%s\n' "${value#b}"
            ;;
        *)
            printf '%s\n' "${fallback}"
            ;;
    esac
}

dpad_value() {
    local key="${1}"
    local fallback="${2}"
    local value

    value="$(mapping_value "${key}")"
    case "${value}" in
        b[0-9]*)
            printf '%s\n' "${value#b}"
            ;;
        *)
            printf '%s\n' "${fallback}"
            ;;
    esac
}

axis_number() {
    local key="${1}"
    local fallback="${2}"
    local value

    value="$(mapping_value "${key}")"
    case "${value}" in
        a[0-9]*)
            printf '%s\n' "$(( ${value#a} + 1 ))"
            ;;
        *)
            printf '%s\n' "${fallback}"
            ;;
    esac
}

write_sdl_gmuinput() {
    local btn_a btn_b btn_x btn_y
    local btn_l btn_r btn_select btn_start btn_menu btn_lstick btn_rstick
    local dpad_up dpad_down dpad_left dpad_right
    local axis_x axis_y

    btn_a="$(button_value a 0)"
    btn_b="$(button_value b 1)"
    btn_x="$(button_value x 2)"
    btn_y="$(button_value y 3)"
    btn_l="$(button_value leftshoulder 4)"
    btn_r="$(button_value rightshoulder 5)"
    btn_select="$(button_value back 6)"
    btn_start="$(button_value start 7)"
    btn_menu="$(button_value guide 8)"
    btn_lstick="$(button_value leftstick 9)"
    btn_rstick="$(button_value rightstick 10)"
    dpad_up="$(dpad_value dpup 200)"
    dpad_down="$(dpad_value dpdown 201)"
    dpad_left="$(dpad_value dpleft 202)"
    dpad_right="$(dpad_value dpright 203)"
    axis_x="$(axis_number leftx 1)"
    axis_y="$(axis_number lefty 2)"

    cat > "${GMUINPUT}" <<'EOF'
FullKeyboard=no
EOF
    {
        printf 'JoyButton-0=%s,A\n' "${btn_a}"
        printf 'JoyButton-1=%s,B\n' "${btn_b}"
        printf 'JoyButton-2=%s,X\n' "${btn_x}"
        printf 'JoyButton-3=%s,Y\n' "${btn_y}"
        printf 'JoyButton-4=%s,L\n' "${btn_l}"
        printf 'JoyButton-5=%s,R\n' "${btn_r}"
        printf 'JoyButton-6=%s,Select\n' "${btn_select}"
        printf 'JoyButton-7=%s,Start\n' "${btn_start}"
        printf 'JoyButton-8=%s,Menu\n' "${btn_menu}"
        printf 'JoyButton-9=%s,StickClick\n' "${btn_lstick}"
        printf 'JoyButton-10=%s,HelpI\n' "${btn_rstick}"
        printf 'JoyButton-11=%s,Up\n' "${dpad_up}"
        printf 'JoyButton-12=%s,Down\n' "${dpad_down}"
        printf 'JoyButton-13=%s,Left\n' "${dpad_left}"
        printf 'JoyButton-14=%s,Right\n' "${dpad_right}"
        printf 'JoyAxis-0=-%s,Left\n' "${axis_x}"
        printf 'JoyAxis-1=%s,Right\n' "${axis_x}"
        printf 'JoyAxis-2=-%s,Up\n' "${axis_y}"
        printf 'JoyAxis-3=%s,Down\n' "${axis_y}"
    } >> "${GMUINPUT}"
}

if [ ! -f "${GMUCONFIG}" ]; then
    cp /usr/share/gmu/batocera/gmu.conf "${GMUCONFIG}"
fi

write_sdl_gmuinput
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
