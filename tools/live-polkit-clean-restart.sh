#!/bin/sh
set -eu
echo '=== Stop the old authorization daemon ==='
rc-service polkit stop
for pid in $(pidof polkitd || true); do
    test "$(readlink "/proc/$pid/exe")" = /usr/lib/polkit-1/polkitd
    test "$(awk '/^Uid:/ {print $2}' "/proc/$pid/status")" = "$(id -u polkitd)"
    echo "Stopping leftover Polkit PID $pid"
    kill -TERM "$pid"
done
sleep 2
if pidof polkitd >/dev/null; then echo 'Old Polkit is still running' >&2; exit 1; fi
cat > /etc/conf.d/polkit <<'EOF'
# Start under the final service identity so proc self-access remains usable.
command_user="polkitd:polkitd"
# A blank argument string keeps diagnostic output (no --no-debug redirect).
POLKIT_OPTS=" "
output_log="/var/log/gta4l/polkit.log"
error_log="/var/log/gta4l/polkit.log"
EOF
rc-service polkit start
rc-service gta4l-dbus-services start
sleep 1
pid=$(pidof polkitd)
test -n "$pid"
grep -E 'Uid:|Gid:|CapEff:' "/proc/$pid/status"
ls -ld "/proc/$pid/fdinfo"
echo '=== Authorization result ==='
su tablet -c 'pkcheck --action-id org.freedesktop.NetworkManager.network-control --process "$$"' || true
su tablet -c 'nmcli general permissions'
tail -n 50 /var/log/gta4l/polkit.log
echo POLKIT_CLEAN_RESTART_END
