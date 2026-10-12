#!/bin/sh
set -eu
printf '%s\n' 'c785f220937932205a1ebf080fec7617444804f91cac3b53d49b9577d0fee30c  /tmp/gta4l-upload/runtime-strace.tar.gz' | sha256sum -c -
mkdir -p /tmp/gta4l-trace
tar -xzf /tmp/gta4l-upload/runtime-strace.tar.gz -C /tmp/gta4l-trace
pid=$(pidof polkitd)
test -n "$pid"
LD_LIBRARY_PATH=/tmp/gta4l-trace/lib timeout 8 /tmp/gta4l-trace/bin/strace -f -s 256 \
    -e trace=openat,read,close,fstat,statx,pidfd_open,pidfd_send_signal \
    -o /tmp/gta4l-trace/polkit-process.log -p "$pid" &
tracer=$!
sleep 1
su tablet -c 'pkcheck --action-id org.freedesktop.NetworkManager.network-control --process "$$"' || true
wait "$tracer" || true
echo '=== Process identity syscall trace ==='
grep -E -A 3 -B 2 'pidfd|fdinfo|/proc/[0-9]+/(stat|status)|EOPNOTSUPP|ENOSYS|EACCES|ENOENT|EINVAL' /tmp/gta4l-trace/polkit-process.log | tail -n 180
echo POLKIT_PROCESS_TRACE_END
