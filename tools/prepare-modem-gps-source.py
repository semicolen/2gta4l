"""Fetch the pinned Alpine ModemManager sources for the SoC GPS quirk."""
from pathlib import Path
import hashlib
import re
import tarfile
import urllib.request

base=Path('/home/ark/sm-t505-port')
ws=Path('/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os')
recipe=(ws/'downloads/gps-integration-reference/modemmanager-APKBUILD').read_text()
commit=re.search(r'^_commit=(\S+)',recipe,re.M)[1]
assert commit=='7f0bf17ab518cd78925cf7e53cc0d5c42f88b41a'
name='ModemManager-'+commit+'.tar.gz'
archive=base/'downloads'/name
if not archive.exists():
    archive.write_bytes(urllib.request.urlopen('https://gitlab.freedesktop.org/mobile-broadband/ModemManager/-/archive/'+commit+'/'+name,timeout=30).read())
digest=hashlib.sha512(archive.read_bytes()).hexdigest()
assert re.search(r'^'+digest+r'\s+'+re.escape(name)+r'$',recipe,re.M)
folder=base/'sources/modemmanager-gps-inspect'
folder.mkdir(parents=True,exist_ok=True)
with tarfile.open(archive) as tar: tar.extractall(folder,filter='data')
port=ws/'port/modemmanager'
port.mkdir(exist_ok=True)
(port/'APKBUILD').write_text(recipe.replace('pkgrel=0','pkgrel=1'))
for name in ['modemmanager.rules','modemmanager.initd','0001-intel-XMM7360-fix-big-endian-handling-of-ASN-integer.patch']:
    data=urllib.request.urlopen('https://gitlab.alpinelinux.org/alpine/aports/-/raw/master/community/modemmanager/'+name,timeout=20).read()
    assert re.search(r'^'+hashlib.sha512(data).hexdigest()+r'\s+'+re.escape(name)+r'$',recipe,re.M)
    (port/name).write_bytes(data)
(base/'work/cache_distfiles'/archive.name).write_bytes(archive.read_bytes())
print('Verified pinned ModemManager source:',digest)
