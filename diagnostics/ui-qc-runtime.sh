#!/bin/sh
# Read-only first-boot state; save output privately because logs can identify devices.
set -u
printf 'UI_QC_FIRST_BOOT\n'
uname -a
cat /etc/os-release
uptime
df -h / /boot
printf '\nPort and UI packages\n'
apk info -v | sort | grep -E '^(device-samsung-gta4l|linux-samsung-gta4l|camera-gta4l|gps-gta4l|alsa-ucm-gta4l|modemmanager|postmarketos-ui-|xfce4-session|gnome-shell|gnome-session|mutter|plasma-mobile|kwin-|sway-|tinydm-|lightdm-|gdm-|sddm-)'
printf '\nServices\n'
rc-status -a
printf '\nSession processes\n'
ps -o pid,ppid,user,args | grep -E 'lightdm|tinydm|sddm|gdm|Xorg|xfce4|gnome-shell|kwin|sway|onboard|maliit|squeekboard|wvkbd|pulseaudio|gta4l' | grep -v grep
printf '\nNetwork devices\n'
ip -brief address
nmcli -t -f DEVICE,TYPE,STATE device
printf '\nModem discovery\n'
mmcli -L
printf '\nBluetooth\n'
timeout 5 bluetoothctl show
printf '\nDisplay connectors\n'
for path in /sys/class/drm/card*-*/status; do
    [ -f "$path" ] || continue
    printf '%s: ' "$path"
    cat "$path"
done
printf '\nInput devices\n'
cat /proc/bus/input/devices
printf '\nBattery/charger state\n'
for supply in battery cw2017-battery usb; do
    for attribute in status capacity voltage_now current_now temp charge_full charge_full_design charge_counter; do
        path="/sys/class/power_supply/$supply/$attribute"
        [ -f "$path" ] || continue
        printf '%s %s: ' "$supply" "$attribute"
        cat "$path"
    done
done
printf '\nRecent kernel messages\n'
dmesg | tail -n 180
printf '\nUI_QC_FIRST_BOOT_END\n'
