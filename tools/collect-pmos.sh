#!/bin/sh
# Run as root on the tablet after booting this image. Only reads hardware state.
set -u
out="${1:-/tmp/gta4l-diagnostics}"
mkdir -p "$out"
capture() {
    name="$1"
    shift
    "$@" > "$out/$name.txt" 2>&1 || true
}
capture kernel uname -a
capture boot cat /proc/cmdline
capture dmesg dmesg
capture modules lsmod
capture mounts cat /proc/mounts
capture inputs cat /proc/bus/input/devices
capture addresses ip address
capture routes ip route
capture network nmcli device
capture qrtr qrtr-lookup
capture modems mmcli -L
capture bluetooth bluetoothctl list
capture alsa-cards cat /proc/asound/cards
capture alsa-pcm cat /proc/asound/pcm
capture mixer amixer -c 0 scontents
capture graphics ls -l /dev/fb0 /dev/dri /sys/class/graphics /sys/class/backlight
capture camera ls -l /dev/video0 /dev/media0
{
    for supply in /sys/class/power_supply/*; do
        [ -d "$supply" ] || continue
        printf '\n%s\n' "$supply"
        for field in type status online capacity voltage_now current_now temp; do
            [ -r "$supply/$field" ] || continue
            printf '%s: ' "$field"
            cat "$supply/$field"
        done
    done
} > "$out/power.txt"
printf 'Diagnostics saved to %s\n' "$out"
