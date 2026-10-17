#!/usr/bin/env python3
from pathlib import Path
import subprocess
import tarfile

stock = Path('/mnt/c/Users/darya/Downloads/Samfw/SAMFW.COM_SM-T505_NEE_T505XXS8CXG1_fac')
target = Path('/home/ark/sm-t505-port/stock')
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
