"""Fetch official Alpine location recipe files for inspection and local builds."""
from pathlib import Path
import concurrent.futures
import urllib.request

root=Path(__file__).resolve().parents[1]
out=root/'downloads/gps-integration-reference'
out.mkdir(parents=True,exist_ok=True)
items=[
 ('geoclue-APKBUILD','https://gitlab.alpinelinux.org/alpine/aports/-/raw/master/community/geoclue/APKBUILD'),
 ('modemmanager-APKBUILD','https://gitlab.alpinelinux.org/alpine/aports/-/raw/master/community/modemmanager/APKBUILD'),
 ('geoclue-conf','https://gitlab.freedesktop.org/geoclue/geoclue/-/raw/2.8.2/data/geoclue.conf.in'),
]
def fetch(item):
    name,url=item
    try:
        with urllib.request.urlopen(url,timeout=20) as r:
            data=r.read(1024*1024)
        assert not data.lstrip().startswith(b'<!DOCTYPE'), 'HTML response'
        (out/name).write_bytes(data)
        return name, len(data)
    except Exception as e: return name, str(e)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    for result in pool.map(fetch,items): print(*result)
