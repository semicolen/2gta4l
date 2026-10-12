#!/bin/sh
set -eu
echo '=== Polkit account ==='
getent passwd polkitd
getent group polkitd
pid=$(pidof polkitd)
grep -E 'Uid:|Gid:|CapEff:|NoNewPrivs:' "/proc/$pid/status"
ls -ld "/proc/$pid/fdinfo"
if [ -e /etc/conf.d/polkit ]; then
    echo 'Existing Polkit configuration; refusing an unreviewed overwrite' >&2
    exit 1
fi
cat > /etc/conf.d/polkit <<'EOF'
# Start under the final service identity. A root-to-polkitd privilege drop
# makes /proc/self/fdinfo unreadable on this downstream kernel.
command_user="polkitd:polkitd"
output_log="/var/log/gta4l/polkit.log"
error_log="/var/log/gta4l/polkit.log"
EOF
rc-service polkit restart
sleep 1
pid=$(pidof polkitd)
grep -E 'Uid:|Gid:|CapEff:|NoNewPrivs:' "/proc/$pid/status"
ls -ld "/proc/$pid/fdinfo"
echo '=== Authorization after service identity change ==='
su tablet -c 'pkcheck --action-id org.freedesktop.NetworkManager.network-control --process "$$"' || true
su tablet -c 'nmcli general permissions'
tail -n 60 /var/log/gta4l/polkit.log
echo POLKIT_SERVICE_USER_END
