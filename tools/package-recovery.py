#!/usr/bin/env python3
"""Add a model/partition preflight to a locally built recovery ZIP."""
from pathlib import Path
import argparse
import shutil
import subprocess
import hashlib
import json
import re
import tarfile
import zipfile

p = argparse.ArgumentParser()
p.add_argument('source', type=Path)
p.add_argument('output', type=Path)
p.add_argument('--expected-boot',type=Path)
p.add_argument('--rootfs-report',type=Path)
p.add_argument('--report',type=Path)
p.add_argument('--package-revision',type=int,default=2)
a = p.parse_args()
workspace = Path(__file__).resolve().parents[1]
with zipfile.ZipFile(a.source) as z:
    names = z.namelist()
    if len(names) != len(set(names)):
        raise SystemExit('Duplicate entries in source ZIP')
    original = z.read('META-INF/com/google/android/update-binary')
    if original != Path('/home/ark/sm-t505-port/sources/recovery-installer/update-binary').read_bytes():
        raise SystemExit('Recovery installer differs from the audited upstream source')
    upstream = Path('/home/ark/sm-t505-port/sources/recovery-installer')
    patched = {}
    for name in ['pmos_install', 'pmos_install_functions']:
        data = z.read('chroot/bin/' + name)
        assert data == (upstream / name).read_bytes(), 'Unexpected upstream ' + name
        patched['chroot/bin/' + name] = data
    marker = b'partition_install_device || :'
    assert patched['chroot/bin/pmos_install'].count(marker) == 1
    patched['chroot/bin/pmos_install'] = patched['chroot/bin/pmos_install'].replace(
        marker, b'partition_install_device || { ui_print "Partition setup failed; formatting and boot flashing stopped."; exit 1; }')
    patched['chroot/bin/pmos_install'] = patched['chroot/bin/pmos_install'].replace(
        b'# parted returns nonzero even when command executed successfully',
        b'# SM-T505 partition setup must succeed before formatting')
    patched['chroot/bin/pmos_install_functions'] += b'\n' + (workspace / 'recovery/partition-functions.sh').read_bytes()
    patched['gta4l_userdata_mounts.sh'] = (workspace / 'recovery/userdata-mounts.sh').read_bytes()
    options = dict(re.findall(r"^([A-Z_]+)='([^']*)'$", z.read('chroot/install_options').decode(), re.M))
    expected = dict(DEVICE='samsung-gta4l', FLASH_KERNEL='true', ISOREC='false',
                    KERNEL_PARTLABEL='boot', INITFS_PARTLABEL='recovery',
                    SYSTEM_PARTLABEL='userdata', INSTALL_PARTITION='userdata', FDE='false')
    assert all(options.get(key) == value for key, value in expected.items()), options
    expected_boot = (a.expected_boot or workspace / 'artifacts/boot.img').read_bytes()
    verified = (a.rootfs_report or workspace / 'artifacts/rootfs-verification.json').read_text()
    expected_loader = json.loads(verified)['autoload_modules']
    found_boot = found_loader = False
    with z.open('rootfs.tar.gz') as stream, tarfile.open(fileobj=stream, mode='r|gz') as tar:
        for member in tar:
            if member.name.lstrip('./') == 'boot/boot.img':
                assert tar.extractfile(member).read() == expected_boot, 'ZIP contains a different boot image'
                found_boot = True
            elif member.name.lstrip('./') == 'etc/modules-load.d/gta4l.conf':
                assert tar.extractfile(member).read().decode().splitlines() == expected_loader, 'ZIP module list differs'
                found_loader = True
            if found_boot and found_loader:
                break
    assert found_boot and found_loader, 'ZIP lacks verified kernel or module list'
stage = Path('/home/ark/sm-t505-port/recovery-stage')
meta = stage / 'META-INF/com/google/android'
meta.mkdir(parents=True, exist_ok=True)
(meta / 'update-binary.pmos').write_bytes(original)
shutil.copyfile(workspace / 'recovery/update-binary', meta / 'update-binary')
for f in meta.iterdir():
    f.chmod(0o755)
for name, data in patched.items():
    target = stage / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    target.chmod(0o755)
a.output.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(a.source, a.output)
members = ['META-INF/com/google/android/update-binary', 'META-INF/com/google/android/update-binary.pmos', *patched]
subprocess.run(['zip', '-q', str(a.output.resolve()), *members], cwd=stage, check=True)
with zipfile.ZipFile(a.output) as z:
    assert len(z.namelist()) == len(set(z.namelist())), 'Duplicate final ZIP entries'
    bad = z.testzip()
    if bad:
        raise SystemExit('Corrupt ZIP member: ' + bad)
print(a.output)
(a.report or workspace / 'artifacts/installer-verification.json').write_text(json.dumps(dict(
    install_options=options, upstream_installer_sha256=hashlib.sha256(original).hexdigest(),
    installer_revision=2, package_revision=a.package_revision, recovery_mount_view='/proc/1/mountinfo',
    partition_setup='staged sparse-file MBR, checked readback and kpartx mappings',
    patched_members_sha256={name: hashlib.sha256((stage / name).read_bytes()).hexdigest() for name in members},
    embedded_boot_matches=True, embedded_module_loader_matches=True,
    zip_crc_checks_passed=True, runtime_verified=False), indent=2) + '\n')
