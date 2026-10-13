#!/usr/bin/env python3
"""Capture the two upstream Plasma recipes with downstream OpenRC metadata."""
from pathlib import Path
import re,shutil
workspace=Path(__file__).resolve().parents[1]
source=Path('/home/pmos/sm-t505-port/sources/pmaports/main')
target=workspace/'ui-profiles/aports'
for name in ('postmarketos-ui-plasma-mobile','postmarketos-ui-plasma-desktop'):
    destination=target/name
    # Preserve the captured overlay on subsequent invocations.
    if destination.exists():continue
    original=(source/name/'APKBUILD').read_text()
    assert 'pmb:support-openrc' not in original
    assert 'openrc()' in original and '$pkgname-openrc.post-install' in original
    shutil.copytree(source/name,destination)
    updated=re.sub(r'^pkgrel=(\d+)',lambda m:'pkgrel='+str(int(m[1])+1),original,flags=re.M)
    updated=updated.replace('pmb:support-systemd"','pmb:support-systemd pmb:support-openrc"')
    assert updated!=original and 'pmb:support-openrc' in updated
    (destination/'APKBUILD').write_text(updated)
print('Prepared two downstream OpenRC Plasma recipes')
