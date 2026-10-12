"""Prepare a checksum-verified official GeoClue package for a local WSL build."""
from pathlib import Path
import hashlib
import re
import tarfile
import urllib.request

base=Path('/home/pmos/sm-t505-port')
ws=Path('/mnt/c/postmarketOS-gta4l')
reference=ws/'downloads/gps-integration-reference'
recipe=(reference/'geoclue-APKBUILD').read_text()
assert re.search(r'^pkgver=2.8.2$',recipe,re.M)
url='https://gitlab.freedesktop.org/geoclue/geoclue/-/archive/2.8.2/geoclue-2.8.2.tar.bz2'
archive=base/'downloads/geoclue-2.8.2.tar.bz2'
if not archive.exists():
    archive.write_bytes(urllib.request.urlopen(url,timeout=30).read())
digest=hashlib.sha512(archive.read_bytes()).hexdigest()
assert re.search(r'^'+digest+r'\s+geoclue-2.8.2.tar.bz2$',recipe,re.M), 'GeoClue archive hash mismatch'
folder=base/'sources/geoclue-inspect'
folder.mkdir(parents=True,exist_ok=True)
with tarfile.open(archive) as tar: tar.extractall(folder,filter='data')
port=ws/'port/geoclue'
port.mkdir(exist_ok=True)
(port/'APKBUILD').write_text(recipe)
preinstall=urllib.request.urlopen('https://gitlab.alpinelinux.org/alpine/aports/-/raw/master/community/geoclue/geoclue.pre-install',timeout=20).read()
assert preinstall.startswith(b'#!/bin/sh')
(port/'geoclue.pre-install').write_bytes(preinstall)
cache=base/'work/cache_distfiles'/archive.name
cache.write_bytes(archive.read_bytes())
print('GeoClue source verified:',digest)
print('Official pre-install script:')
print(preinstall.decode())
