"""Inspect system runtime directories through a temporary read-only loop device."""
from pathlib import Path
import hashlib
import struct
import subprocess

raw = Path('/home/ark/sm-t505-port/stock/vendor/super.raw.img')
with raw.open('rb') as stream:
    stream.seek(12288)
    initial = stream.read(128)
    magic, major, minor, header_size = struct.unpack_from('<IHHI', initial)
    assert magic == 0x414c5030 and major == 10
    stream.seek(12288)
    header = bytearray(stream.read(header_size))
    expected = bytes(header[12:44])
    header[12:44] = bytes(32)
    assert hashlib.sha256(header).digest() == expected
    tables = stream.read(struct.unpack_from('<I', header, 44)[0])
    assert hashlib.sha256(tables).digest() == header[48:80]
    po, pn, ps = struct.unpack_from('<III', header, 80)
    eo, en, es = struct.unpack_from('<III', header, 92)
    for i in range(pn):
        rec = tables[po+i*ps:po+(i+1)*ps]
        if rec[:36].split(b'\0')[0] != b'system':
            continue
        attrs, first, count, group = struct.unpack_from('<IIII', rec, 36)
        assert count == 1 and first < en
        sectors, typ, sector, source = struct.unpack_from('<QIQI', tables, eo+first*es)
        assert typ == 0 and source == 0
        offset, length = sector*512, sectors*512
        assert offset+length <= raw.stat().st_size
        break
    else:
        raise SystemExit('No system partition')

device = subprocess.check_output(['losetup', '--find', '--show', '--read-only',
    '--offset', str(offset), '--sizelimit', str(length), str(raw)], text=True).strip()
try:
    for directory in ['/', '/system', '/system/apex', '/system/lib64', '/system/bin']:
        p = subprocess.run(['debugfs', '-R', 'ls -p '+directory, device],
            text=True, capture_output=True, check=True)
        print(directory)
        for row in p.stdout.splitlines():
            fields = row.split('/')
            if len(fields) < 7:
                continue
            name = fields[5]
            if directory in ['/', '/system', '/system/apex'] or name in (
                'linker64', 'libc.so', 'libdl.so', 'libm.so', 'libcutils.so',
                'libutils.so', 'libcamera_metadata.so', 'libhardware.so'):
                print(row)
finally:
    subprocess.run(['losetup', '--detach', device], check=True)
