#!/usr/bin/env python3
from pathlib import Path
import subprocess
import tarfile

stock = Path('/mnt/c/stock-firmware/SM-T505')
target = Path('/home/pmos/sm-t505-port/stock')
archive = next(stock.glob('BL_*.tar.md5'))
with tarfile.open(archive) as tar:
    print([(m.name, m.size) for m in tar.getmembers()], flush=True)
    for member in tar.getmembers():
        # Extract firmware containers only; no bootloader images are modified.
        if member.name not in {'NON-HLOS.bin.lz4', 'dspso.bin.lz4', 'apnhlos.bin.lz4', 'bluetooth.img.lz4', 'bluetooth.bin.lz4'}:
            continue
        src = tar.extractfile(member)
        assert src is not None
        compressed = target / member.name
        with compressed.open('wb') as out:
            while chunk := src.read(1024 * 1024):
                out.write(chunk)
        raw = compressed.with_suffix('')
        subprocess.run(['lz4', '-d', '-f', str(compressed), str(raw)], check=True)
        subprocess.run(['file', str(raw)], check=True)
        subprocess.run(['mdir', '-i', str(raw), '::'], check=False)
