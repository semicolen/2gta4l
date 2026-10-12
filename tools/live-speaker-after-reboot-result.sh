#!/bin/sh
set -eu
export XDG_RUNTIME_DIR=/run/user/10000
echo '=== Automatic desktop playback result ==='
cat /home/tablet/.cache/gta4l-speaker-reboot-test.log
grep -qx 'AUTOMATIC_DESKTOP_PLAYBACK_STATUS=0' /home/tablet/.cache/gta4l-speaker-reboot-test.log
echo '=== Automatically detected audio card ==='
su tablet -s /bin/sh -c 'pactl list short cards; pactl list short sinks'
echo '=== Current Wi-Fi route ==='
ip -4 route show default
interface=$(ip -4 route show default | awk '/ dev / {print $5; exit}')
case "$interface" in wlan0|swlan0) ;; *) echo 'No Wi-Fi default route' >&2; exit 1 ;; esac
ping -4 -I "$interface" -c 3 -W 3 postmarketos.org
echo SPEAKER_AFTER_REBOOT_RESULT_END
