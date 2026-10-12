#!/usr/bin/env python3
"""Verify bounds and allowed edits against the matching private stock NVM."""
from pathlib import Path
import hashlib
import importlib.util
import struct
import tarfile

workspace = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bootstrap', workspace/'port/bluetooth-gta4l/gta4l-bt-initialize.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with tarfile.open(workspace/'firmware-local/gta4l-firmware-T505XXS8CXG1.tar.gz') as archive:
    data = archive.extractfile(next(x for x in archive if x.name.endswith('/apnv11.bin'))).read()
assert hashlib.sha256(data).hexdigest() == module.NVM_SHA
original = bytes(data)
address = bytes.fromhex('001122334455')
converted = module.prepare_nvm(data, address)
inner_length = struct.unpack_from('<I', data, 4)[0] >> 8
stock_bt = data[4:8+inner_length]
assert len(converted) == len(stock_bt)
allowed = set()
offset = 4
while offset < len(converted):
    tag, size, _, _ = struct.unpack_from('<HHII', converted, offset)
    start = offset+12
    if tag == 2:
        allowed.update(range(start, start+6))
        assert converted[start:start+6] == address[::-1]
    elif tag == 17:
        allowed.update([start, start+2])
        assert converted[start] == (stock_bt[start] & ~0x80)
        assert converted[start+2] == 0
    elif tag == 27:
        allowed.add(start)
        assert converted[start] == (stock_bt[start] & ~1)
    offset = start+size
assert all(a == b or i in allowed for i, (a, b) in enumerate(zip(stock_bt, converted)))
assert data == original, 'Original stock container changed'
for corrupt in [data[:-1], data[:4], b'\x02'+data[1:]]:
    try:
        module.prepare_nvm(corrupt, address)
    except AssertionError:
        pass
    else:
        raise AssertionError('Malformed NVM accepted')
print('STOCK_BT_NVM_ALLOWED_EDITS_AND_BOUNDS_PASS')
