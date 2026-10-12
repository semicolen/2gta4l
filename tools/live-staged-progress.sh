stty -echo
printf '\nGTA4L_PROGRESS_BEGIN\n'
cat /proc/uptime /proc/sys/kernel/panic
rc-status -a
ps -eo pid,ppid,stat,wchan:24,args
for file in /var/log/gta4l/staged-*.log; do
    [ ! -f "$file" ] || { printf '\nLOG:%s\n' "$file"; tail -60 "$file"; }
done
printf '\nGTA4L_PROGRESS_END\n'
stty echo
