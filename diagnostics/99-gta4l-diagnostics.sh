#!/bin/busybox ash
# Initramfs cleanup hook, after root/boot mounts and before switch_root.
set -eu
out=/sysroot/var/log/gta4l
mkdir -p "$out"
chmod 700 "$out"
for name in initramfs.log pre-handoff-dmesg.log kernel-live.log collector.log; do
    [ ! -f "$out/$name" ] || mv -f "$out/$name" "$out/$name.previous"
done
cp /pmOS_init.log "$out/initramfs.log"
dmesg > "$out/pre-handoff-dmesg.log"
cat /proc/cmdline > "$out/cmdline.txt"
if ! grep -q '^# BEGIN GTA4L DIAGNOSTIC LOGGING$' /sysroot/etc/rc.conf; then
    cp -p /sysroot/etc/rc.conf "$out/rc.conf.before-debug"
    cat >> /sysroot/etc/rc.conf <<'EOF'

# BEGIN GTA4L DIAGNOSTIC LOGGING
rc_logger="YES"
rc_log_path="/var/log/rc.log"
rc_verbose="YES"
# END GTA4L DIAGNOSTIC LOGGING
EOF
fi
touch "$out/kernel-live.log" "$out/collector.log"
sync
/gta4l-bootlog /dev/kmsg "$out/kernel-live.log" </dev/null >"$out/collector.log" 2>&1 &
echo "$!" > "$out/collector.pid"
sync
echo 'SM-T505 diagnostics: persistent kernel log and OpenRC startup logging enabled'
