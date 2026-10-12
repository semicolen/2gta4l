#!/bin/sh
set -eu
/usr/libexec/rc/bin/checkpath -f -m 0600 -o polkitd:polkitd /var/log/gta4l/polkit.log
cat > /etc/conf.d/polkit <<'EOF'
# Keep Polkit's proc self-access usable on the downstream kernel.
command_user="polkitd:polkitd"
POLKIT_OPTS=" "
output_log="/var/log/gta4l/polkit.log"
error_log="/var/log/gta4l/polkit.log"
start_pre() {
    checkpath -f -m 0600 -o polkitd:polkitd /var/log/gta4l/polkit.log
}
EOF
rc-service polkit restart
rc-service gta4l-dbus-services start
sleep 1
pid=$(pidof polkitd)
test -n "$pid"
grep -E 'Uid:|Gid:|CapEff:' "/proc/$pid/status"
ls -ld "/proc/$pid/fdinfo"
echo '=== User permissions after clean launch ==='
su tablet -c 'pkcheck --action-id org.freedesktop.NetworkManager.network-control --process "$$"' || true
su tablet -c 'nmcli general permissions'
tail -n 40 /var/log/gta4l/polkit.log
echo POLKIT_LOG_PERMISSIONS_FIX_END
