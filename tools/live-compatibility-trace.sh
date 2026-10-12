#!/bin/sh
set -eu
printf '%s\n' 'c785f220937932205a1ebf080fec7617444804f91cac3b53d49b9577d0fee30c  /tmp/gta4l-upload/runtime-strace.tar.gz' | sha256sum -c -
mkdir -p /tmp/gta4l-trace
tar -xzf /tmp/gta4l-upload/runtime-strace.tar.gz -C /tmp/gta4l-trace
export LD_LIBRARY_PATH=/tmp/gta4l-trace/lib
/tmp/gta4l-trace/bin/strace -V
set +e
/tmp/gta4l-trace/bin/strace -o /tmp/gta4l-trace/sysusers.log -e trace=statx,openat2,openat,readlinkat /usr/bin/systemd-sysusers --dry-run
echo "Sysusers dry-run exit: $?"
tail -n 70 /tmp/gta4l-trace/sysusers.log
echo '=== ModemManager output destinations ==='
for pid in $(pidof ModemManager); do
    readlink /proc/$pid/exe /proc/$pid/fd/1 /proc/$pid/fd/2
done
cat /usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service
echo COMPATIBILITY_TRACE_END
