#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
exec python3 "$ROOT/sources/pmbootstrap/pmbootstrap.py" --as-root -c '/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os/tools/pmbootstrap.cfg' "$@"
