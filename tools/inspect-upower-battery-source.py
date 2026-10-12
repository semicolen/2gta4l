#!/usr/bin/env python3
"""Fetch the exact installed UPower source into local WSL for inspection."""
from pathlib import Path
import hashlib,io,tarfile,urllib.request
root=Path('/home/pmos/sm-t505-port/sources/upower-battery-audit')
root.mkdir(parents=True,exist_ok=True)
archive=root/'upower-v1.91.0.tar.bz2'
expected='32801d3ee4c5086221a9f12062b0f2e6765b239f68a562c24ef7808999bb34e299e6acd31acf5c414cf41613709c97b20ad64d252e1d8ddf23183576b156cf93'
if not archive.exists():
    request=urllib.request.Request('https://gitlab.freedesktop.org/upower/upower/-/archive/v1.91.0/upower-v1.91.0.tar.bz2',headers={'User-Agent':'gta4l-local-battery-audit'})
    with urllib.request.urlopen(request,timeout=30) as response:
        data=response.read(5*1024*1024)
    if hashlib.sha512(data).hexdigest()!=expected:raise SystemExit('UPower source hash mismatch')
    archive.write_bytes(data)
data=archive.read_bytes()
if hashlib.sha512(data).hexdigest()!=expected:raise SystemExit('Cached UPower source hash mismatch')
with tarfile.open(fileobj=io.BytesIO(data),mode='r:bz2') as tar:
    for member in tar.getmembers():
        relative=Path(*Path(member.name).parts[1:])
        if member.isfile() and relative.suffix in ('.c','.h','.py','.in') and relative.parts and relative.parts[0] in ('src','etc'):
            if '..' in relative.parts:raise SystemExit('Invalid archive path')
            target=root/relative
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(tar.extractfile(member).read())
print('UPower 1.91.0 exact source SHA512 verified; selected source files saved locally')
