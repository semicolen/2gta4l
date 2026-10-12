#!/bin/sh
set -eu
ROOT=/home/pmos/sm-t505-port
echo '=== Firmware transfer protocol ==='
sed -n '112,267p' "$ROOT/kernel/drivers/bluetooth/btqca.c"
cat "$ROOT/kernel/drivers/bluetooth/btqca.h" | head -n 180
echo '=== Stock file headers ==='
python3 - <<'PY'
from pathlib import Path
import hashlib
import tarfile
root = Path('/mnt/c/postmarketOS-gta4l')
with tarfile.open(root/'firmware-local/gta4l-firmware-T505XXS8CXG1.tar.gz') as archive:
    for item in archive:
        if Path(item.name).name not in ['apbtfw11.tlv', 'apnv11.bin']: continue
        data = archive.extractfile(item).read()
        print(item.name, len(data), hashlib.sha256(data).hexdigest(), data[:48].hex())
PY
