#!/bin/sh
set -eu
find /sys/kernel/debug/ipc_logging -maxdepth 2 -type f -name log | grep -E 'uart|serial|ttyHS' || true
for entry in /sys/kernel/debug/ipc_logging/*uart* /sys/kernel/debug/ipc_logging/*ttyHS* /sys/kernel/debug/ipc_logging/*serial*; do
    [ -d "$entry" ] || continue
    echo "=== $entry ==="
    [ ! -f "$entry/log" ] || head -c 65536 "$entry/log"
done
