#!/usr/bin/env python3
"""Create a public default-account build from verified r14, locally in WSL."""
from pathlib import Path, PurePosixPath
from datetime import datetime, timezone
import copy
import ctypes
import ctypes.util
import gzip
import hashlib
import io
import json
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import zipfile

from ui_build_recipe import fingerprint, tested_kernel

assert sys.platform == 'linux' and Path('/home/ark/sm-t505-port').is_dir(), 'Run in WSL Ubuntu'
workspace = Path(__file__).resolve().parents[1]
builds = workspace/'artifacts/ui-builds'
receipt = json.loads((builds/'gnome-verification.json').read_text())
root_report = json.loads((builds/'gnome-rootfs-verification.json').read_text())
assert receipt['ui'] == 'gnome' and receipt['package_revision'] == 14
assert receipt['recipe_sha256'] == fingerprint(workspace, 'gnome')
assert root_report['checks_passed'] and receipt['embedded_modules_verified'] == 37
source = builds/receipt['package']
release = workspace/'artifacts/releases/SM-T505-GNOME-Desktop-r15'
release.mkdir(parents=True, exist_ok=True)
destination = release/'Nura-SM-T505-OrangeFox-GNOME-Desktop-r15.zip'
assert not destination.exists(), 'Public image exists; review it before replacing it'


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


assert source.stat().st_size == receipt['bytes'] and sha256(source) == receipt['sha256']
boot, kernel = tested_kernel(workspace)
assert kernel['boot_sha256'] == receipt['boot_sha256']
private_password = re.search(r'^Password: (.+)$',
                            (workspace/'artifacts/initial-login.txt').read_text(), re.M)[1].encode()
private_hashes = []
with zipfile.ZipFile(source) as archive:
    with archive.open('rootfs.tar.gz') as compressed:
        with tarfile.open(fileobj=compressed, mode='r|gz') as rootfs:
            for member in rootfs:
                if member.name.removeprefix('./') == 'etc/shadow':
                    shadow = rootfs.extractfile(member).read().decode()
                    private_hashes = [line.split(':')[1].encode() for line in shadow.splitlines()
                                      if line.split(':')[1].startswith('$')]
                    break
assert private_hashes, 'Private source account hash was not identified'
secret_values = [private_password, *private_hashes]
private_key = re.compile(rb'-----BEGIN (?:OPENSSH |RSA |EC |DSA |ENCRYPTED )?PRIVATE KEY-----\r?\n[A-Za-z0-9+/]{32}')
root = Path('/home/ark/sm-t505-port/ui-work/gnome/chroot_rootfs_samsung-gta4l')
# GnuTLS embeds public self-test keys in its library. Permit that exact signed
# distro payload only, not arbitrary PEM data in other files or modified ELF.
# https://gitlab.com/gnutls/gnutls/-/blob/3.8.13/lib/crypto-selftests-pk.c
fixture_libraries = {}
gnutls_apks = list(Path('/home/ark/sm-t505-port/work/cache_apk_aarch64').glob('gnutls-3.8.13-r0.*.apk'))
assert len(gnutls_apks) == 1
subprocess.run(['/home/ark/sm-t505-port/work/apk.static', '--keys-dir', str(root/'etc/apk/keys'),
                'verify', str(gnutls_apks[0])], check=True, capture_output=True)
with tarfile.open(gnutls_apks[0], 'r:gz', ignore_zeros=True) as signed_package:
    for member in signed_package:
        name = member.name.removeprefix('./')
        if member.isfile() and name.startswith('usr/lib/libgnutls.so.'):
            data = signed_package.extractfile(member).read()
            assert data.startswith(b'\x7fELF')
            if private_key.search(data):
                fixture_libraries[name] = hashlib.sha256(data).hexdigest()
assert fixture_libraries


def scan(data, label):
    assert not any(value in data for value in secret_values), 'Private credential in '+label
    assert label in fixture_libraries or not private_key.search(data), 'Private key in '+label


# Verify that the exact retained ramdisk does not contain private credentials.
boot_data = boot.read_bytes()
page = struct.unpack_from('<I', boot_data, 36)[0]
kernel_size, _, ramdisk_size = struct.unpack_from('<3I', boot_data, 8)
ramdisk_offset = page + ((kernel_size+page-1)//page)*page
ramdisk = gzip.decompress(boot_data[ramdisk_offset:ramdisk_offset+ramdisk_size])
scan(ramdisk, 'retained boot ramdisk')
assert not re.search(rb'(?:ssh_host_[a-z0-9]+_key|authorized_keys)\x00', ramdisk), 'Private SSH identity in boot'
del ramdisk, boot_data
password_hash = subprocess.check_output(['openssl', 'passwd', '-6', '-stdin'], input=b'147147\n').strip().decode()
crypt = ctypes.CDLL(ctypes.util.find_library('crypt'))
crypt.crypt.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
crypt.crypt.restype = ctypes.c_char_p
assert crypt.crypt(b'147147', password_hash.encode()) == password_hash.encode()
assert crypt.crypt(b'wrong-password', password_hash.encode()) != password_hash.encode()
target_check = '''import ctypes,sys
lib=ctypes.CDLL(None)
lib.crypt.argtypes=[ctypes.c_char_p,ctypes.c_char_p]
lib.crypt.restype=ctypes.c_char_p
stored=sys.stdin.buffer.read().strip()
assert lib.crypt(b"147147",stored)==stored
assert lib.crypt(b"wrong-password",stored)!=stored
print("ARM64_DEFAULT_PASSWORD_VERIFIED")
'''
target_result = subprocess.run(['chroot', str(root), '/usr/bin/python3', '-c', target_check],
                               input=password_hash+'\n', text=True, capture_output=True, timeout=30)
assert target_result.returncode == 0, target_result.stderr
assert target_result.stdout.strip() == 'ARM64_DEFAULT_PASSWORD_VERIFIED'

changed = {}
omitted = {}
expected_files = {}
identities = {}
omitted_prefixes = ('root/', 'home/', 'var/log/', 'var/lib/NetworkManager/',
                    'etc/NetworkManager/system-connections/', 'var/lib/bluetooth/',
                    'tmp/', 'run/', 'var/cache/apk/')
backup_names = {'etc/passwd-', 'etc/group-', 'etc/shadow-', 'etc/gshadow-'}


def omit(name, member):
    if name in backup_names or name == 'var/lib/dbus/machine-id':
        return True
    if name.startswith('etc/ssh/ssh_host_') or PurePosixPath(name).name in ('authorized_keys', 'authorized_keys2'):
        return True
    return any(name.startswith(prefix) for prefix in omitted_prefixes) and not member.isdir()


def account_data(name, data):
    text = data.decode()
    lines = []
    for line in text.splitlines():
        fields = line.split(':')
        if name == 'etc/passwd' and fields[0] == 'tablet':
            assert fields[2:4] == ['10000', '10000'] and fields[5] == '/home/tablet'
            fields[0], fields[5] = 'user', '/home/user'
        elif name == 'etc/group':
            if fields[0] == 'tablet':
                fields[0] = 'user'
            fields[3] = ','.join('user' if value == 'tablet' else value for value in fields[3].split(','))
        elif name == 'etc/shadow':
            if fields[0] == 'tablet':
                fields[0], fields[1] = 'user', password_hash
            elif fields[1].startswith('$') or not fields[1]:
                fields[1] = '!'
        elif name == 'etc/gshadow':
            if fields[0] == 'tablet':
                fields[0] = 'user'
            for index in (2, 3):
                fields[index] = ','.join('user' if value == 'tablet' else value for value in fields[index].split(','))
        elif name in ('etc/subuid', 'etc/subgid') and fields[0] == 'tablet':
            fields[0] = 'user'
        lines.append(':'.join(fields))
    output = ('\n'.join(lines)+'\n').encode()
    identities[name] = output
    return output


class CheckedReader:
    def __init__(self, stream, name):
        self.stream, self.name = stream, name
        self.digest, self.tail = hashlib.sha256(), b''

    def read(self, size=-1):
        data = self.stream.read(size)
        scan(self.tail+data, self.name)
        self.tail = (self.tail+data)[-1024:]
        self.digest.update(data)
        return data


print('PUBLIC_BUILD_INPUT_AND_RAMDISK_VERIFIED', flush=True)
with tempfile.TemporaryDirectory(prefix='gnome-public-', dir='/home/ark/sm-t505-port') as temporary:
    temporary = Path(temporary)
    archive_path = temporary/'rootfs.tar.gz'
    with archive_path.open('wb') as compressed_output:
        compressor = subprocess.Popen(['gzip', '-1', '-c'], stdin=subprocess.PIPE, stdout=compressed_output)
        try:
            with zipfile.ZipFile(source) as original, original.open('rootfs.tar.gz') as compressed_input:
                with tarfile.open(fileobj=compressed_input, mode='r|gz') as incoming, \
                     tarfile.open(fileobj=compressor.stdin, mode='w|') as outgoing:
                    for member in incoming:
                        name = member.name.removeprefix('./')
                        assert not name.startswith('/') and '..' not in PurePosixPath(name).parts
                        if omit(name, member):
                            category = next((prefix for prefix in omitted_prefixes if name.startswith(prefix)), 'identity/backups')
                            omitted[category] = omitted.get(category, 0)+1
                            continue
                        member = copy.copy(member)
                        if member.uname == 'tablet': member.uname = 'user'
                        if member.gname == 'tablet': member.gname = 'user'
                        if not member.isfile():
                            outgoing.addfile(member)
                            continue
                        stream = incoming.extractfile(member)
                        if name in ('etc/passwd', 'etc/group', 'etc/shadow', 'etc/gshadow', 'etc/subuid', 'etc/subgid'):
                            old = stream.read()
                            new = account_data(name, old)
                        elif name == 'etc/machine-id':
                            old, new = stream.read(), b''
                        else:
                            reader = CheckedReader(stream, name)
                            outgoing.addfile(member, reader)
                            if name in fixture_libraries:
                                assert reader.digest.hexdigest() == fixture_libraries[name], name
                            expected_files[name] = reader.digest.hexdigest()
                            continue
                        scan(new, name)
                        if old != new:
                            changed[name] = hashlib.sha256(new).hexdigest()
                        member.size = len(new)
                        outgoing.addfile(member, io.BytesIO(new))
                        expected_files[name] = hashlib.sha256(new).hexdigest()
        finally:
            compressor.stdin.close()
            assert compressor.wait() == 0, 'Rootfs compression failed'
    assert {'etc/passwd', 'etc/group', 'etc/shadow'} <= changed.keys()
    assert identities['etc/passwd'].count(b'\nuser:') == 1
    assert b'\ntablet:' not in identities['etc/passwd'] and b'quickUser:' not in identities['etc/passwd']
    passwd = dict((line.split(':')[0], line.split(':')) for line in identities['etc/passwd'].decode().splitlines())
    assert [name for name, values in passwd.items() if 1000 <= int(values[2]) < 60000] == ['user']
    groups = dict((line.split(':')[0], line.split(':')) for line in identities['etc/group'].decode().splitlines())
    assert all('user' in groups[group][3].split(',') for group in ('wheel', 'video', 'audio', 'netdev', 'plugdev'))
    print('PUBLIC_ACCOUNT_PRIVACY_AND_ROOTFS_TRANSFORM_COMPLETE', len(expected_files), 'regular files', flush=True)
    candidate = temporary/'public.zip'
    installer_hashes = {}
    with zipfile.ZipFile(source) as original, zipfile.ZipFile(candidate, 'w', allowZip64=True) as output:
        for member in original.infolist():
            if member.filename == 'rootfs.tar.gz':
                output.write(archive_path, member.filename, compress_type=zipfile.ZIP_STORED)
            else:
                data = original.read(member)
                scan(data, 'installer '+member.filename)
                installer_hashes[member.filename] = hashlib.sha256(data).hexdigest()
                output.writestr(member, data)
    print('VERIFYING_PUBLIC_IMAGE_PAYLOAD_AND_CRC', flush=True)
    checked = set()
    with zipfile.ZipFile(candidate) as output:
        assert len(output.namelist()) == len(set(output.namelist()))
        assert output.testzip() is None
        for name, digest in installer_hashes.items():
            assert hashlib.sha256(output.read(name)).hexdigest() == digest, name
        with output.open('rootfs.tar.gz') as compressed:
            with tarfile.open(fileobj=compressed, mode='r|gz') as archive:
                for member in archive:
                    name = member.name.removeprefix('./')
                    assert not omit(name, member), 'Private state retained: '+name
                    if not member.isfile(): continue
                    reader = CheckedReader(archive.extractfile(member), name)
                    while reader.read(1024*1024): pass
                    assert reader.digest.hexdigest() == expected_files[name], name
                    if name in fixture_libraries:
                        assert reader.digest.hexdigest() == fixture_libraries[name], name
                    checked.add(name)
    assert checked == set(expected_files)
    for name, digest in kernel['modules_sha256'].items():
        assert expected_files.get(name, expected_files.get('usr/'+name)) == digest, name
    assert expected_files['boot/boot.img'] == kernel['boot_sha256']
    public_hash = sha256(candidate)
    partial = destination.with_suffix('.zip.partial')
    shutil.copyfile(candidate, partial)
    assert sha256(partial) == public_hash
    partial.replace(destination)

verification = {
    'device': 'SM-T505', 'ui': 'GNOME Desktop', 'revision': 15,
    'build_host': 'WSL Ubuntu', 'built_at_utc': datetime.now(timezone.utc).isoformat(),
    'package': destination.name, 'bytes': destination.stat().st_size, 'sha256': public_hash,
    'source_r14_package_sha256': receipt['sha256'],
    'default_username': 'user', 'default_password': '147147',
    'default_password_hash_verified_with_libcrypt': True,
    'default_password_negative_test_passed': True,
    'arm64_musl_default_password_and_negative_tests_passed': True,
    'crypto_selftest_fixture_libraries_match_signed_distro_package': fixture_libraries,
    'uid_gid_preserved': '10000:10000',
    'hardware_and_wheel_groups_verified': True,
    'only_public_regular_account': True, 'private_credentials_and_keys_scan_passed': True,
    'rootfs_regular_files_verified': len(checked), 'changed_files_sha256': changed,
    'omitted_state_counts': omitted,
    'all_other_retained_file_payloads_identical_to_verified_r14': True,
    'boot_sha256': kernel['boot_sha256'], 'embedded_driver_modules_verified': 37,
    'selected_packages': receipt['selected_packages'],
    'installer_payloads_byte_identical': True,
    'zip_crc_checks_passed': True, 'local_checks_passed': True,
    'formats_userdata': True, 'preserves_partitions': receipt['preserves_partitions'],
    'first_boot': 'GNOME login with user / 147147',
    'clean_install_tablet_qc_complete': False,
}
(release/'build-verification.json').write_text(json.dumps(verification, indent=2)+'\n')
shutil.copyfile(workspace/'PUBLIC-RELEASE.md', release/'INSTALL.md')
files = sorted(path for path in release.iterdir() if path.is_file() and path.name != 'SHA256SUMS')
(release/'SHA256SUMS').write_text(''.join(sha256(path)+'  '+path.name+'\n' for path in files))
print('PUBLIC_GNOME_R15_READY', destination.name, destination.stat().st_size, public_hash, flush=True)
