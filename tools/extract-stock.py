#!/usr/bin/env python3
"""Extract only required stock images. Never changes the source firmware."""
import pathlib
import subprocess
import tarfile

stock = pathlib.Path('/mnt/c/stock-firmware/SM-T505')
target = pathlib.Path('/home/pmos/sm-t505-port/stock')
target.mkdir(parents=True, exist_ok=True)
for prefix, names in [('AP_', {'boot.img.lz4', 'recovery.img.lz4', 'dtbo.img.lz4', 'vbmeta.img.lz4'}), ('CP_', {'modem.bin.lz4', 'NON-HLOS.bin.lz4'})]:
    archive = next(stock.glob(prefix + '*.tar.md5'))
    with tarfile.open(archive) as tar:
        print(archive.name, [(m.name, m.size) for m in tar.getmembers()], flush=True)
        for member in tar.getmembers():
            if member.name not in names:
                continue
            src = tar.extractfile(member)
            assert src is not None
            compressed = target / member.name
            with compressed.open('wb') as dest:
                while chunk := src.read(1024 * 1024):
                    dest.write(chunk)
            subprocess.run(['lz4', '-d', '-f', str(compressed), str(compressed.with_suffix(''))], check=True)
subprocess.run(['python3', '/home/pmos/sm-t505-port/sources/orangefox/tools/extract_stock_boot.py', str(target / 'boot.img'), str(target / 'boot')], check=True)
subprocess.run(['python3', '/home/pmos/sm-t505-port/sources/orangefox/tools/extract_stock_boot.py', str(target / 'recovery.img'), str(target / 'recovery')], check=True)
