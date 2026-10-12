stty -echo
printf '\nGTA4L_DESKTOP_RADIO_BEGIN\n'
uname -a
cat /proc/uptime
getent passwd tablet
ls -l /usr/share/xsessions
cat /etc/lightdm/lightdm.conf
find /etc/lightdm/lightdm.conf.d -maxdepth 1 -type f -exec cat {} \;
rc-status -a
ip -br link
ls -l /sys/class/net /sys/class/bluetooth /dev/ttyHS* /dev/btpower /dev/subsys* /dev/cdc* /dev/wwan* 2>/dev/null
mmcli -L
nmcli -t -f DEVICE,TYPE,STATE device
cat /proc/asound/cards
for f in /sys/class/power_supply/*/uevent; do echo "$f"; cat "$f"; done
printf '\nGTA4L_DESKTOP_RADIO_END\n'
stty echo
