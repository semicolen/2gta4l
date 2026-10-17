"""Fetch the official Alpine recipe and checksum-verified Xfce source in WSL."""
from pathlib import Path
import hashlib
import re
import tarfile
import urllib.request

base = Path('/home/ark/sm-t505-port')
folder = base/'sources/lockscreen-inspect'
folder.mkdir(parents=True, exist_ok=True)
recipe = urllib.request.urlopen('https://raw.githubusercontent.com/alpinelinux/aports/master/community/xfce4-screensaver/APKBUILD', timeout=30).read().decode()
(folder/'APKBUILD').write_text(recipe)
print(recipe)
version = re.search(r'^pkgver=(\S+)', recipe, re.M).group(1)
assert version == '4.20.2'
archive = base/f'downloads/xfce4-screensaver-{version}.tar.xz'
if not archive.exists():
    archive.write_bytes(urllib.request.urlopen(f'https://archive.xfce.org/src/apps/xfce4-screensaver/4.20/xfce4-screensaver-{version}.tar.xz', timeout=30).read())
digest = hashlib.sha512(archive.read_bytes()).hexdigest()
assert re.search(rf'^{digest}\s+{re.escape(archive.name)}$', recipe, re.M), 'Source checksum mismatch'
with tarfile.open(archive) as tar:
    tar.extractall(folder, filter='data')
print('XFCE_SOURCE_SHA512_VERIFIED', digest)
patch = urllib.request.urlopen('https://raw.githubusercontent.com/alpinelinux/aports/master/community/xfce4-screensaver/pam-base-auth.patch', timeout=30).read()
assert re.search(rf'^{hashlib.sha512(patch).hexdigest()}\s+pam-base-auth.patch$', recipe, re.M)
(folder/'pam-base-auth.patch').write_bytes(patch)
