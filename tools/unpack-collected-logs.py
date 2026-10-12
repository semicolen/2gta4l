#!/usr/bin/env python3
"""Extract only regular files under var/log from a collected rootfs archive."""
from pathlib import Path, PurePosixPath
import sys
import tarfile

source, destination = map(Path, sys.argv[1:3])
count = 0
with tarfile.open(source, 'r:gz') as archive:
    for item in archive.getmembers():
        name = PurePosixPath(item.name)
        assert not name.is_absolute() and '..' not in name.parts
        assert name.parts[:2] == ('var', 'log')
        if not item.isfile():
            continue
        assert item.size <= 32 * 1024 * 1024
        target = destination.joinpath(*name.parts[2:])
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(archive.extractfile(item).read())
        count += 1
print(f'Extracted {count} regular log files')
