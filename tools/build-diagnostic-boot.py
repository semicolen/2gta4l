#!/usr/bin/env python3
"""Repack the verified local boot with a log collector and late initramfs hook."""
from pathlib import Path
import argparse
import gzip
import hashlib
import json
import struct
import subprocess
import zipfile

workspace = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--revision', type=int, choices=[1, 2, 3], default=1)
parser.add_argument('--installed-boot', type=Path)
args = parser.parse_args()
suffix = '' if args.revision == 1 else f'-r{args.revision}'
installed = (args.installed_boot or workspace / 'artifacts/boot.img').read_bytes()
source = workspace / 'artifacts/boot.img'
data = source.read_bytes()
ks, ka, rs, ra, ss, sa, ta, page, version, osv = struct.unpack_from('<10I', data, 8)
assert version == 2 and page == 4096 and ss == 0
align = lambda value: (value + page - 1) // page * page
recovery_size, recovery_offset = struct.unpack_from('<IQ', data, 1632)
dtb_size, dtb_address = struct.unpack_from('<IQ', data, 1648)
assert recovery_size == recovery_offset == 0
kernel = data[page:page+ks]
rd_start = page + align(ks)
ramdisk = data[rd_start:rd_start+rs]
dtb_start = rd_start + align(rs)
dtb = data[dtb_start:dtb_start+dtb_size]
trailer = data[dtb_start+align(dtb_size):]
assert trailer == b'SEANDROIDENFORCE'

def image_id(rd):
    digest = hashlib.sha1()
    for payload in [kernel, rd, b'', b'', dtb]:
        digest.update(payload)
        digest.update(struct.pack('<I', len(payload)))
    return digest.digest() + bytes(12)

assert image_id(ramdisk) == data[576:608], 'Unexpected upstream boot image ID algorithm'
cpio = gzip.decompress(ramdisk)
offset = 0
names = set()
inode = 1
chunks = []
patched_functions = None
patched_mode = None
while True:
    start = offset
    header = cpio[offset:offset+110]
    assert header[:6] == b'070701'
    fields = [int(header[6+i*8:14+i*8], 16) for i in range(13)]
    inode = max(inode, fields[0]+1)
    name = cpio[offset+110:offset+110+fields[11]-1].decode().lstrip('./')
    offset = (offset + 110 + fields[11] + 3) // 4 * 4
    if name == 'TRAILER!!!':
        cpio = b''.join(chunks)
        break
    names.add(name)
    payload_start = offset
    offset = (offset + fields[6] + 3) // 4 * 4
    if args.revision == 3 and name == 'init_functions.sh':
        functions = cpio[payload_start:payload_start + fields[6]].decode()
        begin = functions.index('\t# Remove the ACM/mass storage gadget devices\n')
        end = functions.index('\n\tsplash_set_message "Loading"', begin)
        cleanup = functions[begin:end]
        assert cleanup.count('setup_usb_configfs_udc') == 1
        guarded = '\tif [ ! -e /gta4l-keep-debug-usb ]; then\n' + cleanup + '\tfi\n'
        patched_functions = (functions[:begin] + guarded + functions[end:]).encode()
        patched_mode = fields[1]
    else:
        chunks.append(cpio[start:offset])

def entry(name, payload, mode):
    global inode
    fields = [inode, mode, 0, 0, 2 if mode & 0o170000 == 0o040000 else 1,
              0, len(payload), 0, 0, 0, 0, len(name)+1, 0]
    inode += 1
    record = b'070701' + b''.join(f'{value:08x}'.encode() for value in fields) + name.encode() + b'\0'
    record += bytes(-len(record) % 4)
    record += payload
    record += bytes(-len(record) % 4)
    return record

collector = Path('/home/ark/sm-t505-port/diagnostics/gta4l-bootlog').read_bytes()
assert collector[:4] == b'\x7fELF' and struct.unpack_from('<H', collector, 18)[0] == 183
hook = (workspace / 'diagnostics/99-gta4l-diagnostics.sh').read_bytes()
assert 'gta4l-bootlog' not in names and 'hooks-cleanup/99-gta4l-diagnostics.sh' not in names
if 'hooks-cleanup' not in names:
    cpio += entry('hooks-cleanup', b'', 0o040755)
cpio += entry('gta4l-bootlog', collector, 0o100755)
cpio += entry('hooks-cleanup/99-gta4l-diagnostics.sh', hook, 0o100755)
if args.revision == 3:
    assert patched_functions is not None
    cpio += entry('init_functions.sh', patched_functions, patched_mode)
    cpio += entry('gta4l-keep-debug-usb', b'', 0o100600)
cpio += entry('TRAILER!!!', b'', 0)
cpio += bytes(-len(cpio) % 512)
new_ramdisk = gzip.compress(cpio, compresslevel=6, mtime=0)
header = bytearray(data[:page])
struct.pack_into('<I', header, 16, len(new_ramdisk))
header[576:608] = image_id(new_ramdisk)
old_cmdline = (data[64:576] + data[608:1632]).split(b'\0')[0].decode()
cmdline = 'console=tty0 ' + old_cmdline.strip() + ' pstore.compress=none rd.info loglevel=7'
if args.revision >= 2:
    cmdline += ' pmos.debug-shell panic=15'
assert len(cmdline.encode()) < 511
header[64:576] = cmdline.encode().ljust(512, b'\0')
header[608:1632] = bytes(1024)
pad = lambda payload: payload + bytes(align(len(payload))-len(payload))
new_boot = bytes(header) + pad(kernel) + pad(new_ramdisk) + pad(dtb) + trailer
assert len(new_boot) < 100663296
output = workspace / ('artifacts/boot-diagnostic' + suffix + '.img')
output.write_bytes(new_boot)
digest = hashlib.sha256(new_boot).hexdigest()
updater = (workspace / 'diagnostics/update-binary').read_text()
substitutions = dict(ORIGINAL_BYTES=len(installed), ORIGINAL_SHA256=hashlib.sha256(installed).hexdigest(),
                     DIAGNOSTIC_BYTES=len(new_boot), DIAGNOSTIC_SHA256=digest)
for key, value in substitutions.items():
    updater = updater.replace('@' + key + '@', str(value))
assert '@' not in updater
package = workspace / ('artifacts/postmarketOS-SM-T505-OrangeFox-diagnostic-boot' + suffix + '.zip')
with zipfile.ZipFile(package, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for name, contents in [('META-INF/com/google/android/update-binary', updater.encode()),
                           ('META-INF/com/google/android/updater-script', b'# Boot-only diagnostic update\n'),
                           ('boot.img', new_boot)]:
        info = zipfile.ZipInfo(name)
        info.create_system = 3
        info.external_attr = (0o100755 if name.endswith('update-binary') else 0o100644) << 16
        archive.writestr(info, contents, compress_type=zipfile.ZIP_DEFLATED, compresslevel=6)
with zipfile.ZipFile(package) as archive:
    assert archive.testzip() is None
    assert archive.read('boot.img') == new_boot
native = Path('/home/ark/sm-t505-port/diagnostics')
(native / 'update-binary').write_text(updater)
subprocess.run(['sh', '-n', str(native / 'update-binary')], check=True)
subprocess.run(['sh', '-n', str(workspace / 'diagnostics/99-gta4l-diagnostics.sh')], check=True)
subprocess.run(['python3', str(workspace / 'tools/verify-boot.py'), str(output), str(workspace / ('artifacts/diagnostic-boot' + suffix + '-verification.json'))], check=True)
report = dict(build_host='WSL Ubuntu', original_boot_sha256=hashlib.sha256(data).hexdigest(),
              installed_before_sha256=hashlib.sha256(installed).hexdigest(), revision=args.revision,
              diagnostic_boot_sha256=digest, diagnostic_boot_bytes=len(new_boot),
              package_sha256=hashlib.sha256(package.read_bytes()).hexdigest(),
              kernel_unchanged=True, dtb_unchanged=True, cmdline=cmdline,
              added_initramfs_files=['gta4l-bootlog', 'hooks-cleanup/99-gta4l-diagnostics.sh'],
              collector_sha256=hashlib.sha256(collector).hexdigest(),
              collector_static_arm64=True, setup_tests_passed=True, runtime_verified=False,
              installer_partition_writes=['boot'], formats_userdata=False)
report['debug_exit_usb_rebind_skipped'] = args.revision == 3
report['modified_initramfs_files'] = ['init_functions.sh'] if args.revision == 3 else []
(workspace / ('artifacts/diagnostic-update' + suffix + '-verification.json')).write_text(json.dumps(report, indent=2) + '\n')
print(package)
print(json.dumps(report, indent=2))
