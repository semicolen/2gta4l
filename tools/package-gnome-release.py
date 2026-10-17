#!/usr/bin/env python3
"""Stage the verified GNOME Desktop image and first-boot notes locally in WSL."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import shutil
import sys
import tarfile
import zipfile

from ui_build_recipe import fingerprint

assert sys.platform == 'linux' and Path('/home/ark/sm-t505-port').is_dir(), 'Run locally in WSL Ubuntu'
workspace = Path(__file__).resolve().parents[1]
builds = workspace / 'artifacts/ui-builds'
receipt = json.loads((builds / 'gnome-verification.json').read_text())
root_receipt = json.loads((builds / 'gnome-rootfs-verification.json').read_text())
assert receipt['ui'] == 'gnome' and receipt['package_revision'] == 14
assert receipt['build_host'] == 'WSL Ubuntu' and root_receipt['checks_passed']
assert receipt['recipe_sha256'] == fingerprint(workspace, 'gnome'), 'Build recipe changed'
assert receipt['embedded_modules_verified'] == 37
assert receipt['embedded_apk_database_verified'] and receipt['apk_signing_keys_verified']
assert receipt['formats_userdata'] and 'recovery' in receipt['preserves_partitions']
source = builds / receipt['package']


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


assert source.stat().st_size == receipt['bytes']
assert sha256(source) == receipt['sha256']
print('VERIFIED_RELEASE_INPUT', flush=True)
found = {}
forced_setup = False
with zipfile.ZipFile(source) as installer:
    assert installer.testzip() is None, 'Installer ZIP CRC failed'
    with installer.open('rootfs.tar.gz') as compressed:
        with tarfile.open(fileobj=compressed, mode='r|gz') as archive:
            for member in archive:
                name = member.name.removeprefix('./')
                assert not name.startswith('home/'), 'User home data in release'
                if name == 'var/lib/gdm/run-initial-setup':
                    forced_setup = True
                if name in ('etc/passwd', 'etc/gdm/custom.conf', 'lib/apk/db/installed',
                            'usr/lib/apk/db/installed') and member.isfile():
                    found[name] = archive.extractfile(member).read().decode()
assert not forced_setup
users = [line.split(':') for line in found['etc/passwd'].splitlines()]
assert any(user[0] == 'tablet' and 1000 <= int(user[2]) < 60000 for user in users)
assert not any(user[0] == 'quickUser' for user in users), 'Private development account in release'
gdm = found['etc/gdm/custom.conf']
assert 'AutomaticLoginEnable=True' not in gdm
database = found.get('lib/apk/db/installed', found.get('usr/lib/apk/db/installed', ''))
packages = {}
for section in database.split('\n\n'):
    values = dict(line.split(':', 1) for line in section.splitlines() if ':' in line)
    if 'P' in values:
        packages[values['P']] = values['V']
assert 'openrc' in packages and 'postmarketos-ui-gnome' in packages
assert 'postmarketos-ui-os-installer' not in packages and 'systemd' not in packages
assert packages['snapshot'] == '51.0-r1' and packages['alsa-ucm-gta4l'] == '1.0-r4'
print('EMBEDDED_FIRST_BOOT_CONFIGURATION_VERIFIED', flush=True)

release = workspace / 'artifacts/releases/SM-T505-GNOME-Desktop-r14'
release.mkdir(parents=True, exist_ok=True)
destination = release / source.name
if not destination.exists() or sha256(destination) != receipt['sha256']:
    partial = destination.with_suffix('.zip.partial')
    shutil.copyfile(source, partial)
    assert sha256(partial) == receipt['sha256']
    partial.replace(destination)
assert sha256(destination) == receipt['sha256']
shutil.copyfile(workspace / 'FIRST-BOOT.md', release / 'INSTALL.md')
for name in ('gnome-verification.json', 'gnome-rootfs-verification.json',
             'gnome-installer-verification.json'):
    shutil.copyfile(builds / name, release / name)
manifest = {
    'device': 'Samsung Galaxy Tab A7 SM-T505',
    'ui': 'GNOME Desktop',
    'package': destination.name,
    'bytes': receipt['bytes'],
    'sha256': receipt['sha256'],
    'prepared_in': 'WSL Ubuntu',
    'prepared_at_utc': datetime.now(timezone.utc).isoformat(),
    'identical_to_verified_r14_ui_image': True,
    'expected_first_boot': 'GDM login using the pre-created tablet account',
    'nura_account_setup_wizard_enabled': False,
    'first_boot_configuration_checked_in_embedded_rootfs': True,
    'zip_crc_verified': True,
    'local_build_verified': True,
    'clean_r14_install_qc_complete': False,
    'formats_userdata': True,
    'preserves_partitions': receipt['preserves_partitions'],
    'private_development_account_included': False,
}
(release / 'release-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
files = sorted(path for path in release.iterdir() if path.is_file() and path.name != 'SHA256SUMS')
assert all(not path.name.endswith('.partial') for path in files)
(release / 'SHA256SUMS').write_text(''.join(sha256(path) + '  ' + path.name + '\n' for path in files))
print('GNOME_DESKTOP_RELEASE_READY', destination.name, receipt['bytes'], receipt['sha256'], flush=True)
