#!/usr/bin/env python3
from pathlib import Path
import hashlib

root = Path('/home/pmos/sm-t505-port/stock')
dirs = [root / 'vendor/root/firmware', root / 'modem-files/image', root / 'apnhlos-files/image']
seen = {}
for directory in dirs:
    for f in directory.rglob('*'):
        if not f.is_file() or f.is_symlink():
            continue
        name = str(f.relative_to(directory))
        digest = hashlib.sha256(f.read_bytes()).hexdigest()
        if name in seen and seen[name][0] != digest:
            print('Conflicting firmware:', name, seen[name][1], directory)
        seen[name] = (digest, directory)
firmware = Path('/home/pmos/sm-t505-port/firmware-stage/lib/firmware/postmarketos')
for name in ['modem.mdt', 'adsp.mdt', 'adsp2.mdt', 'cdsp.mdt', 'a610_zap.mdt', 'a630_sqe.fw', 'wlanmdsp.mbn', 'Himax_firmware_inx_fhd.bin']:
    path = firmware / name
    print(name, path.stat().st_size if path.exists() else 'MISSING')
print('Bluetooth firmware:', [f.name for f in firmware.glob('*bt*')])
