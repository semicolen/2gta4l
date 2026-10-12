#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json
import tarfile

native = Path('/home/pmos/sm-t505-port')
workspace = Path('/mnt/c/postmarketOS-gta4l')
packages = native / 'work/packages/edge/aarch64'
output = workspace / 'artifacts/hci-fix'
output.mkdir(exist_ok=True)

def read_package(path, selected):
    data = {}
    modules = {}
    with tarfile.open(path, 'r:gz', ignore_zeros=True) as archive:
        for member in archive:
            name = member.name.lstrip('./')
            if not member.isfile():
                continue
            if name in selected or name.startswith('lib/modules/'):
                with archive.extractfile(member) as stream:
                    payload = stream.read()
                if name in selected:
                    data[name] = payload
                if name.endswith('.ko'):
                    modules[name] = hashlib.sha256(payload).hexdigest()
    return data, modules

new, new_modules = read_package(packages / 'linux-samsung-gta4l-4.19.300-r3.apk', {'boot/vmlinuz', 'boot/dtbs/qcom/gta4l.dtb'})
old, old_modules = read_package(packages / 'linux-samsung-gta4l-4.19.300-r2.apk', {'boot/vmlinuz', 'boot/dtbs/qcom/gta4l.dtb'})
assert len(new_modules) == len(old_modules) == 35
assert new_modules.keys() == old_modules.keys()
changed_modules = [name for name in new_modules if new_modules[name] != old_modules[name]]
for name, payload in new.items():
    (output / Path(name).name).write_bytes(payload)
report = {
    'kernel_package': 'linux-samsung-gta4l-4.19.300-r3.apk',
    'kernel_sha256': hashlib.sha256(new['boot/vmlinuz']).hexdigest(),
    'old_kernel_sha256': hashlib.sha256(old['boot/vmlinuz']).hexdigest(),
    'dtb_matches_previous_kernel': new['boot/dtbs/qcom/gta4l.dtb'] == old['boot/dtbs/qcom/gta4l.dtb'],
    'driver_module_count': len(new_modules),
    'changed_modules': changed_modules,
}
(output / 'package-comparison.json').write_text(json.dumps(report, indent=2) + '\n')
bwrap, _ = read_package(packages / 'bubblewrap-gta4l-0.13.0-r0.apk', {'usr/bin/bwrap'})
assert bwrap['usr/bin/bwrap'][:4] == b'\x7fELF'
(workspace / 'artifacts/bwrap-gta4l').write_bytes(bwrap['usr/bin/bwrap'])
print(json.dumps(report, indent=2))
