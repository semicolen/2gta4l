#!/usr/bin/env python3
"""Read the installed KWin release's rendering sources from KDE's repository."""
from pathlib import Path
import hashlib
import urllib.request

base = Path('/home/ark/sm-t505-port/diagnostics/kwin-6.7.5')
paths = ('src/plugins/screentransform/screentransform.cpp',
         'src/plugins/screentransform/screentransform.h',
         'src/backends/drm/drm_egl_layer.cpp')
for name in paths:
    url = 'https://invent.kde.org/plasma/kwin/-/raw/v6.7.5/' + name
    content = urllib.request.urlopen(url, timeout=25).read(2 * 1024 * 1024)
    assert b'SPDX' in content and b'<html' not in content[:1000].lower(), url
    target = base/name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(content)
    print(name, len(content), hashlib.sha256(content).hexdigest(), flush=True)
