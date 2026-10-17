#!/usr/bin/env python3
"""Pin a matching, offline, no-hook kernel-file installation to its boot receipt."""
from pathlib import Path
import ast
import hashlib
import json

workspace = Path(__file__).resolve().parents[1]
artifacts = workspace/'artifacts'
report = json.loads((artifacts/'file-access-kernel-fix-verification.json').read_text())
assert report['kernel_build_version'] == '#11-postmarketOS'
assert report['module_count'] == 37 and report['all_driver_modules_byte_identical']
assert report['ramdisk_unchanged'] and report['dtb_unchanged']
package = artifacts/'apks'/report['kernel_package']
assert hashlib.sha256(package.read_bytes()).hexdigest() == report['kernel_package_sha256']
selected = {key: report[key] for key in ('kernel_package', 'kernel_package_sha256',
                                        'expected_installed_boot_bytes', 'expected_installed_boot_sha256')}
script = '''#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib, json, os, subprocess
manifest = __MANIFEST__
assert os.geteuid() == 0
assert '#10-postmarketOS' in subprocess.check_output(['uname','-v'], text=True)
package = Path('/tmp/gta4l-upload')/manifest['kernel_package']
assert hashlib.sha256(package.read_bytes()).hexdigest() == manifest['kernel_package_sha256']
def boot_hash():
    with open('/dev/mmcblk0p69', 'rb') as source:
        return hashlib.sha256(source.read(manifest['expected_installed_boot_bytes'])).hexdigest()
assert boot_hash() == manifest['expected_installed_boot_sha256']
assert int(Path('/sys/class/power_supply/battery/capacity').read_text()) >= 25
assert 'gta4l-gnome-session' in Path('/usr/share/wayland-sessions/gnome.desktop').read_text()
def versions():
    records = {}
    for block in Path('/lib/apk/db/installed').read_text().split('\\n\\n'):
        fields = dict(line.split(':',1) for line in block.splitlines() if ':' in line)
        if 'P' in fields: records[fields['P']] = fields['V']
    return records
before = versions()
assert before['linux-samsung-gta4l'] == '4.19.300-r9'
command = ['apk','--no-network','--no-interactive','--no-scripts','add',str(package)]
trial = subprocess.run(command[:1]+['--simulate']+command[1:], capture_output=True,text=True,check=True)
print(trial.stdout,flush=True)
assert 'Purging' not in trial.stdout
backup = Path('/var/lib/gta4l-ui-qc/kernel11-before')
backup.mkdir(mode=0o700,parents=True,exist_ok=False)
(backup/'versions.json').write_text(json.dumps(before,indent=2)+'\\n')
subprocess.run(command,check=True)
after = versions()
assert after.pop('linux-samsung-gta4l') == '4.19.300-r10'
before.pop('linux-samsung-gta4l')
assert before == after, 'Unrelated package versions changed'
assert boot_hash() == manifest['expected_installed_boot_sha256'], 'Physical boot changed unexpectedly'
os.sync()
print('KERNEL11_FILES_INSTALLED; physical boot remains kernel10; other package versions unchanged',flush=True)
PY
'''.replace('__MANIFEST__', repr(selected))
ast.parse(script.split("<<'PY'\n", 1)[1].rsplit('\nPY', 1)[0])
output = artifacts/'file-access-kernel-fix/install-files.sh'
output.write_text(script, newline='\n')
print('PREPARED_PINNED_KERNEL11_FILES_INSTALLER', output)
