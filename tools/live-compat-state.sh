stty -echo
printf '\nGTA4L_COMPAT_STATE_BEGIN\n'
awk '/^P:/{wanted=($0 ~ /sysusers|tmpfiles|systemd/); name=$0} wanted && /^V:/{print name,$0}' /lib/apk/db/installed
ls -l /sbin/reboot /usr/bin/android-reboot /usr/sbin/android-reboot
command -v python3
tail -120 /var/log/gta4l/staged-sysusers-trace.log
cat /etc/init.d/sysusers /etc/init.d/tmpfiles* /etc/conf.d/zram-init
printf '\nGTA4L_COMPAT_STATE_END\n'
stty echo
