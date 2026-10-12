"""Package stock sensor files without any per-device registry/calibration."""
from pathlib import Path
import hashlib
import re
import tarfile

root = Path(__file__).resolve().parents[1]
source = root / 'firmware-local/sensor-files'
archive = root / 'firmware-local/gta4l-sensor-firmware-T505XXS8CXG1.tar.gz'
old_archive = root / 'downloads/gta4l-sensor-firmware-T505XXS8CXG1.tar.gz'
if old_archive.exists() and not archive.exists():
    old_archive.rename(archive)
archive.parent.mkdir(exist_ok=True)
if not archive.exists():
    with tarfile.open(archive, 'w:gz') as tar:
        tar.add(source/'dsp', arcname='dsp')
        tar.add(source/'sensors/config', arcname='vendor-config')
        tar.add(source/'sensors/sns_reg.conf', arcname='sns_reg.conf')
with tarfile.open(archive) as tar:
    assert all('registry' not in p.name.split('/') for p in tar)
apk = root/'port/firmware-sensors-gta4l/APKBUILD'
text = re.sub(r'sha512sums=".*?"', 'sha512sums="\n' +
              hashlib.sha512(archive.read_bytes()).hexdigest() + '  ' + archive.name + '\n"',
              apk.read_text(), flags=re.S)
apk.write_text(text, newline='\n')
print('Prepared stock-only sensor firmware; factory calibration excluded')
