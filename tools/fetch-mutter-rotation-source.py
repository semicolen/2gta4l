#!/usr/bin/env python3
"""Inspect GNOME's installed Mutter release without changing build sources."""
from pathlib import Path
import hashlib, urllib.request
base=Path('/home/ark/sm-t505-port/diagnostics/mutter-51.0')
for name in ('src/backends/meta-monitor-manager.c','src/backends/meta-backend.c',
             'src/backends/meta-orientation-manager.c','src/backends/native/meta-seat-impl.c',
             'src/backends/native/meta-input-device-native.c','clutter/clutter/clutter-seat.c'):
    target=base/name
    if target.exists():print('CACHED',name,flush=True);continue
    data=urllib.request.urlopen('https://gitlab.gnome.org/GNOME/mutter/-/raw/51.0/'+name,timeout=25).read(2*1024*1024)
    assert b'<html' not in data[:1000].lower() and b'#include' in data
    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
    print(name,len(data),hashlib.sha256(data).hexdigest(),flush=True)
