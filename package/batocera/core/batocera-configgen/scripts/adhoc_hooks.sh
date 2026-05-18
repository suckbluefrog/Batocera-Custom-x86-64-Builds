#!/bin/bash

CHANNEL="6"

adhoc_flag="/tmp/.adhoc_ap_enabled"
adhoc_interface="/tmp/.adhoc_ap_interface"

hostapd_pid="/tmp/hostapd.pid"
hostapd_conf="/tmp/hostapd.conf"

dnsmasq_pid="/tmp/dnsmasq.pid"
dnsmasq_leases="/tmp/dnsmasq.leases"

stop_ap() {
    if [ -f "$hostapd_pid" ]; then
        kill "$(cat "$hostapd_pid")" 2>/dev/null
        rm -f "$hostapd_pid"
    fi

    if [ -f "$dnsmasq_pid" ]; then
        kill "$(cat "$dnsmasq_pid")" 2>/dev/null
        rm -f "$dnsmasq_pid"
    fi

    interface="$(cat "$adhoc_interface" 2>/dev/null)"
    if [ -n "$interface" ]; then
        ip addr flush dev "$interface" 2>/dev/null
    fi

    rm -f "$adhoc_flag" "$adhoc_interface" "$dnsmasq_leases" "$hostapd_conf"
}

should_start_ap() {
    [ "$(batocera-settings-get global.netplay)" = "1" ] || return 1
    [ "$(batocera-settings-get global.netplay.hotspot)" = "1" ] || return 1

    INTERFACE="$(batocera-wifi get_interface)"
    [ -n "$INTERFACE" ] || return 1

    SSID="$(batocera-settings-get wifi.adhoc.ssid)"
    PASSPHRASE="$(batocera-settings-get wifi.adhoc.key)"
    [ -n "$SSID" ] || return 1
    [ "${#PASSPHRASE}" -ge 8 ] || return 1

    if ip -4 addr show "$INTERFACE" | grep -q 'inet '; then
        return 1
    fi

    return 0
}

case "$1" in
    gameStart)
        if should_start_ap; then
            stop_ap
            touch "$adhoc_flag"
            printf '%s\n' "$INTERFACE" > "$adhoc_interface"

            ip link set "$INTERFACE" up
            ip addr flush dev "$INTERFACE"
            sleep 0.1
            ip addr add 192.168.4.1/24 dev "$INTERFACE"

            cat > "$hostapd_conf" <<EOF
interface=$INTERFACE
driver=nl80211
ssid=$SSID
channel=$CHANNEL
hw_mode=g
auth_algs=1
wpa=2
wpa_passphrase=$PASSPHRASE
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

            hostapd "$hostapd_conf" &
            echo $! > "$hostapd_pid"

            dnsmasq --interface="$INTERFACE" \
                    --bind-interfaces \
                    --dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,12h \
                    --dhcp-leasefile="$dnsmasq_leases" \
                    --no-resolv &
            echo $! > "$dnsmasq_pid"

            for _ in $(seq 1 100); do
                if iw dev "$INTERFACE" info | grep -q "type AP"; then
                    break
                fi
                sleep 0.1
            done
        fi
        ;;
    gameStop)
        if [ -f "$adhoc_flag" ]; then
            stop_ap
        fi
        ;;
esac
