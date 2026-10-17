#!/bin/sh
set -eu
command -v gdb || true
apk --no-interactive --simulate add gdb
ls -l /usr/lib/gstreamer-1.0/*jpeg* /usr/lib/gstreamer-1.0/*gtk* 2>/dev/null || true
cat /proc/sys/kernel/core_pattern
