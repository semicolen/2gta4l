stty -echo
printf '\nGTA4L_DEFAULT_BEGIN\n'
(
set -eu
[ ! -e /etc/runlevels/default/bluetooth ]
for level in sysinit boot default; do
    echo "GTA4L_STAGE: OpenRC $level, diagnostic Bluetooth pause" > /dev/kmsg
    /sbin/openrc "$level" || echo "OpenRC $level returned $?"
done
) </dev/null >/var/log/gta4l/staged-default.log 2>&1 &
echo "Default startup task: $!"
printf '\nGTA4L_DEFAULT_END\n'
stty echo
