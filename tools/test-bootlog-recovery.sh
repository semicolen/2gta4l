#!/system/bin/sh
set -eu
binary=/tmp/gta4l-bootlog
printf 'not a kernel device\n' > /tmp/gta4l-bootlog-regular-input
if "$binary" /tmp/gta4l-bootlog-regular-input /tmp/gta4l-rejected.log; then
    echo 'FAIL: accepted a regular input file'; exit 1
else
    [ "$?" = 2 ]
fi
echo 'PASS: collector rejects regular input files'
"$binary" /dev/kmsg /tmp/gta4l-test-kernel-live.log &
pid="$!"
trap 'kill -TERM "$pid" 2>/dev/null || true' EXIT
sleep 2
kill -TERM "$pid"
wait "$pid"
[ -s /tmp/gta4l-test-kernel-live.log ]
echo 'PASS: static ARM64 collector reads real kernel records and stops gracefully'
