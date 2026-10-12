#!/usr/bin/env python3
"""Decode framed pstore transfers and verify each tablet-side SHA256."""
from pathlib import Path
import base64
import hashlib
import json
import re
import sys

source = Path(sys.argv[1])
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
text = source.read_text(encoding='utf-8-sig')
records = []
for match in re.finditer(r'\nGTA4L_FILE:(/sys/fs/pstore/[^\r\n]+|/tmp/gta4l-rootlogs.tar.gz)\r?\n(.*?)\nGTA4L_FILE_END', text, re.S):
    path, block = match.groups()
    name = Path(path).name
    assert re.fullmatch(r'[a-zA-Z0-9_.-]+', name) and name not in ('.', '..')
    expected = re.search(r'^([a-f0-9]{64})\s+' + re.escape(path) + r'\r?$', block, re.M)[1]
    lines = [line.strip() for line in block.splitlines() if re.fullmatch(r'[A-Za-z0-9+/=]+', line.strip())]
    data = base64.b64decode(''.join(lines), validate=True)
    digest = hashlib.sha256(data).hexdigest()
    assert digest == expected, name
    (out / name).write_bytes(data)
    records.append(dict(name=name, bytes=len(data), sha256=digest, matches_device=True))
assert re.search(r'^GTA4L_(PSTORE|TRANSFER)_END\r?$', text, re.M), 'Console transfer incomplete'
(out / 'transfer.json').write_text(json.dumps(records, indent=2) + '\n')
print(json.dumps(records, indent=2))
