stty -echo
printf '\nGTA4L_WLAN_START_BEGIN\n'
ls -l /dev/wlan
cat > /tmp/gta4l-start-wlan.sh <<'GTA4L_WLAN_SCRIPT_END'
#!/bin/sh
set -eu
[ -c /dev/wlan ]
echo 'GTA4L_TEST: downstream WLAN userspace ON command' > /dev/kmsg
# Vendor write callback copies exactly three bytes, then matches ON.
printf 'ON\n' > /dev/wlan
echo 'WLAN ON command completed'
ip -br link
GTA4L_WLAN_SCRIPT_END
nohup sh /tmp/gta4l-start-wlan.sh </dev/null >/var/log/gta4l/wlan-start.log 2>&1 &
echo "WLAN startup task: $!"
printf '\nGTA4L_WLAN_START_END\n'
stty echo
