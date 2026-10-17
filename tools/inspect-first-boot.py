#!/usr/bin/env python3
"""Inspect first-boot support without reading account secrets or changing images."""
from pathlib import Path
import re

base = Path('/home/ark/sm-t505-port')
ports = base / 'sources/pmaports'
for name in ('postmarketos-ui-gnome', 'postmarketos-ui-gnome-mobile',
             'postmarketos-ui-os-installer'):
    directory = ports / 'main' / name
    for path in sorted(directory.iterdir()):
        if path.is_file() and path.stat().st_size < 32000:
            try:
                content = path.read_text()
            except UnicodeDecodeError:
                continue
            if path.name == 'APKBUILD':
                content = content.split('sha512sums=', 1)[0]
            print('\nSOURCE', path.relative_to(ports))
            print(content)

for ui in ('gnome', 'gnome-mobile'):
    root = base / 'ui-work' / ui / 'chroot_rootfs_samsung-gta4l'
    records = {}
    for section in (root / 'lib/apk/db/installed').read_text().split('\n\n'):
        values = dict(line.split(':', 1) for line in section.splitlines() if ':' in line)
        if 'P' in values:
            records[values['P']] = values['V']
    print('\nROOTFS', ui)
    for name, version in sorted(records.items()):
        if re.search(r'initial|ondev|os-installer|gdm|accountsservice|welcome', name):
            print('PACKAGE', name, version)
    for relative in ('etc/gdm/custom.conf', 'etc/xdg/autostart/gnome-initial-setup-first-login.desktop',
                     'usr/share/gnome-session/sessions/gnome-initial-setup.session'):
        path = root / relative
        print('EXISTS', relative, path.exists())
        if path.is_file():
            print(path.read_text())
    print('REGULAR_USER_COUNT', sum(1 for line in (root/'etc/passwd').read_text().splitlines()
                                    if 1000 <= int(line.split(':')[2]) < 60000))

pmb = base / 'sources/pmbootstrap/pmb'
pattern = re.compile(r'ondev|initial.setup|os-installer', re.I)
matches = []
for path in pmb.rglob('*.py'):
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if pattern.search(line):
            matches.append(f'{path.relative_to(pmb)}:{number}: {line.strip()}')
print('\nPMBOOTSTRAP_SETUP_REFERENCES')
print('\n'.join(matches[:140]))
