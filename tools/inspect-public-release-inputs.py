#!/usr/bin/env python3
"""Report release-account and installer structure without printing secrets."""
from pathlib import Path
import re
import zipfile

workspace = Path(__file__).resolve().parents[1]
base = Path('/home/ark/sm-t505-port')
image = workspace/'artifacts/ui-builds/postmarketOS-SM-T505-OrangeFox-gnome-r14.zip'
with zipfile.ZipFile(image) as archive:
    content = archive.read('chroot/install_options').decode()
    for key, value in re.findall(r"^([A-Z_]+)='([^']*)'$", content, re.M):
        if any(word in key for word in ('PASS', 'KEY', 'SECRET')):
            print('INSTALL_OPTION', key, 'REDACTED', 'length', len(value))
        elif any(word in key for word in ('USER', 'HOME')):
            print('INSTALL_OPTION', key, value)
root = base/'ui-work/gnome/chroot_rootfs_samsung-gta4l'
for relative in ('etc/passwd', 'etc/group'):
    print('ACCOUNT_FILE', relative)
    for line in (root/relative).read_text().splitlines():
        if 'tablet' in line:
            print(line)
for line in (root/'etc/shadow').read_text().splitlines():
    fields = line.split(':')
    if fields[0] in ('root', 'tablet'):
        print('PASSWORD_STATE', fields[0], 'LOCKED' if fields[1][:1] in ('!', '*') else 'HASH_OR_EMPTY')
for directory in ('etc/ssh', 'etc/NetworkManager/system-connections', 'root', 'var/lib/AccountsService/users'):
    print('PATH_NAMES', directory, sorted(p.name for p in (root/directory).glob('*')))
for relative in ('etc/init.d/dbus', 'etc/init.d/sshd', 'etc/init.d/machine-id'):
    path = root/relative
    if path.is_file():
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if re.search(r'machine.id|keygen|hostkey', line, re.I):
                print('BOOT_IDENTITY_GENERATION', relative, number, line.strip())
print('MACHINE_ID_PATHS', [(name, (root/name).is_symlink(), (root/name).exists())
                           for name in ('etc/machine-id', 'var/lib/dbus/machine-id')])
pmb = base/'sources/pmbootstrap'
print('PMBOOTSTRAP_TOPLEVEL', sorted(p.name for p in pmb.iterdir()))
matches = 0
for path in pmb.rglob('*.py'):
    if '.git' in path.parts or '__pycache__' in path.parts:
        continue
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if 'install_options' in line:
            print('INSTALL_OPTION_SOURCE', path.relative_to(pmb), number, line.strip())
            matches += 1
    if matches >= 30:
        break
