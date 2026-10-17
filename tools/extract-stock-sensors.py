"""Read sensor files from matching stock vendor and the existing persist backup."""
from pathlib import Path
import subprocess
import hashlib
import json
import tarfile

root = Path(__file__).resolve().parents[1]
target = root / 'firmware-local/sensor-files'
target.mkdir(parents=True, exist_ok=True)
vendor = Path('/home/ark/sm-t505-port/stock/vendor/vendor.img')
persist = root / 'artifacts/backups/20261009-214946/persist.img'
assert persist.is_file()

def run(image, command):
    result = subprocess.run(['debugfs', '-R', command, str(image)], check=True, capture_output=True, text=True)
    if 'File not found' in result.stderr:
        raise RuntimeError(result.stderr)

for subdir in ['sensors', 'dsp']:
    (target/subdir).mkdir(exist_ok=True)
run(vendor, f'rdump /etc/sensors/config "{target / "sensors"}"')
run(vendor, f'dump /etc/sensors/sns_reg_config "{target / "sensors/sns_reg.conf"}"')
run(vendor, f'rdump /lib/rfsa/adsp "{target / "dsp"}"')
run(persist, f'rdump /sensors/registry/registry "{target / "sensors"}"')
assert len(list((target/'sensors/registry').iterdir())) > 100
assert len(list((target/'sensors/config').iterdir())) > 20
# rdump adds the source basename. Flatten adsp's contents for HexagonFS -d adsp.
for source in (target/'dsp/adsp').iterdir():
    source.rename(target/'dsp'/source.name)
(target/'dsp/adsp').rmdir()
manifest = {str(p.relative_to(target)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in target.rglob('*') if p.is_file()}
(root/'evidence/stock-sensors').mkdir(exist_ok=True)
(root/'evidence/stock-sensors/SHA256.json').write_text(json.dumps(manifest, indent=2)+'\n')
archive = root/'artifacts/gta4l-sensor-files-private.tar.gz'
with tarfile.open(archive, 'w:gz') as tar:
    tar.add(target, arcname='.', recursive=True)
print(f'Prepared {len(manifest)} private stock sensor files, archive SHA256 {hashlib.sha256(archive.read_bytes()).hexdigest()}')
