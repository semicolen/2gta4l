#!/usr/bin/env python3
from pathlib import Path
import io
import tarfile

root = Path('/home/ark/sm-t505-port/work/chroot_rootfs_samsung-gta4l')
workspace = Path('/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os')
names = {'bin/gdb': root / 'usr/bin/gdb'}
for name in ['libmpfr.so.6', 'libdebuginfod.so.1']:
    names['lib/' + name] = root / 'usr/lib' / name
with tarfile.open(workspace / 'artifacts/runtime-gdb.tar.gz', 'w:gz') as archive:
    for name, source in names.items():
        data = source.read_bytes()
        info = tarfile.TarInfo(name)
        info.size = len(data)
        info.mode = 0o700 if name.startswith('bin/') else 0o600
        archive.addfile(info, io.BytesIO(data))
print('Prepared ARM64 debugger with two additional libraries')
