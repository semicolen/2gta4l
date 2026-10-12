stty -echo
printf '\nGTA4L_SYSUSERS_PROBE_BEGIN\n'
LD_LIBRARY_PATH=/tmp/gta4l-trace/lib /tmp/gta4l-trace/bin/strace -f -s 128 -o /var/log/gta4l/staged-sysusers-trace.log /usr/bin/systemd-sysusers --dry-run
printf 'Sysusers exit: %s\n' "$?"
grep -E 'openat2|ENOSYS|EOPNOTSUPP|faccessat2|statx|writev|exit_group' /var/log/gta4l/staged-sysusers-trace.log | tail -45
awk '/^P:/{wanted=($0 ~ /^P:(bubblewrap|systemd-.*|libglycin|glycin|gdk-pixbuf)$/); name=$0} wanted && /^V:/{print name,$0}' /lib/apk/db/installed
printf '\nGTA4L_SYSUSERS_PROBE_END\n'
stty echo
