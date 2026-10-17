#!/usr/bin/env python3
from pathlib import Path
import hashlib,tarfile
root=Path('/home/ark/sm-t505-port')
archive=root/'work/cache_distfiles/iio-sensor-proxy-3.9.tar.gz'
assert hashlib.sha512(archive.read_bytes()).hexdigest()=='a89c842f8db2a1a36c1c7c990434bb57fd905224459170cba2ec56e79f1272acc4cac4221937704d5e9247f957d86fde716d25e2d1ccb80d88fa643b47edfda6'
destination=root/'diagnostics/sensor-proxy-source'
destination.mkdir(parents=True,exist_ok=True)
with tarfile.open(archive) as source:
    source.extractall(destination,filter='data')
for path in sorted(destination.rglob('*ssc*')):
    if path.is_file() and path.suffix in ('.c','.h'):print(path,flush=True)
