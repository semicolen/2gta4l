#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
python3 "$WORKSPACE/tools/configure-port.py"
cp "$ROOT/sources/tqftpserv-inspect/v1.2.tar.gz" "$ROOT/work/cache_distfiles/tqftpserv-v1.2.tar.gz"
bash "$WORKSPACE/tools/pmb.sh" shutdown
bash "$WORKSPACE/tools/sync-port.sh" build --lax tqftpserv-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/tqftpserv-gta4l-build.log"
rg 'PASS: three stock firmware request paths' "$ROOT/work/log.txt" \
    | tee "$WORKSPACE/logs/tqftpserv-gta4l-translation-test.log"
cp "$ROOT/work/packages/edge/aarch64/tqftpserv-gta4l-1.2-r0.apk" "$WORKSPACE/artifacts/apks/"
