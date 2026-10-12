stty -echo
printf '\nGTA4L_STAGE_SETUP_BEGIN\n'
cat > /tmp/gta4l-staged-init.sh <<'GTA4L_INIT_END'
#!/bin/busybox ash
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
umount /etc/inittab || exit 1
mkdir -p /run/gta4l-diagnostic
echo 'GTA4L_STAGE: diagnostic sysinit reached; OpenRC is paused' > /dev/kmsg
printf '\nSM-T505 staged startup: OpenRC paused; USB console port 2323\n'
telnetd -b 172.16.42.1:2323 -l /bin/sh
echo $$ > /run/gta4l-diagnostic/init.pid
while :; do sleep 3600; done
GTA4L_INIT_END
cat > /hooks-cleanup/100-gta4l-staged-startup.sh <<'GTA4L_HOOK_END'
# One boot only: this hook exists in the initramfs's RAM filesystem.
set -eu
target=/sysroot/sbin/gta4l-staged-init
cp /tmp/gta4l-staged-init.sh "$target"
chmod 700 "$target"
sync
printf '%s\n' '::sysinit:/sbin/gta4l-staged-init' > /tmp/gta4l-staged-inittab
mount -o bind /tmp/gta4l-staged-inittab /sysroot/etc/inittab
echo 'SM-T505: staging startup before OpenRC'
GTA4L_HOOK_END
printf '\nGTA4L_STAGE_SETUP_END\n'
stty echo
