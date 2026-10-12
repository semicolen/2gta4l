#!/usr/bin/env python3
"""Package local WSL ARM64 diagnostics for an isolated /tmp upload."""
from pathlib import Path
import io
import tarfile

root = Path('/home/pmos/sm-t505-port/work/chroot_rootfs_samsung-gta4l')
workspace = Path('/mnt/c/postmarketOS-gta4l')
names = {
    'bin/strace': root / 'usr/bin/strace',
    'lib/libdw.so.1': root / 'usr/lib/libdw.so.1',
}
with tarfile.open(workspace / 'artifacts/runtime-strace.tar.gz', 'w:gz') as archive:
    for name, source in names.items():
        data = source.read_bytes()
        info = tarfile.TarInfo(name)
        info.size = len(data)
        info.mode = 0o700 if name.startswith('bin/') else 0o600
        archive.addfile(info, io.BytesIO(data))
print(f'Created {len(names)} regular files in RAM diagnostic bundle')
