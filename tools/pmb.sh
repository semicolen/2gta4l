#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
exec python3 "$ROOT/sources/pmbootstrap/pmbootstrap.py" --as-root -c '/mnt/c/postmarketOS-gta4l/tools/pmbootstrap.cfg' "$@"
