#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
rg -n 'pidfd_open|pidfd_getfd|pidfd_send_signal|pidfd_fops|pidfd_show_fdinfo|pidfd.*fdinfo' "$ROOT/kernel/kernel" "$ROOT/kernel/fs" "$ROOT/kernel/include" | head -n 100
find "$ROOT/work/cache_apk_aarch64" -maxdepth 1 -name 'polkit-*' -printf '%f\n' 2>/dev/null || true
