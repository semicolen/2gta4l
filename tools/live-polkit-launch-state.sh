#!/bin/sh
set -u
rc-service polkit status
ls -ld /run /var/run /var/log/gta4l
ls -l /var/log/gta4l/polkit.log
tail -n 60 /var/log/gta4l/polkit.log 2>/dev/null
ps -eo pid,ppid,uid,comm,args | grep -E 'polkit|supervise' | grep -v grep
echo '=== Direct unprivileged launch ==='
timeout 3 su -s /bin/sh polkitd -c '/usr/lib/polkit-1/polkitd' 2>&1
echo "direct_launch_status=$?"
echo POLKIT_LAUNCH_STATE_END
