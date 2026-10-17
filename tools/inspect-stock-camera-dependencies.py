"""Inspect matching stock camera ELF dependencies without running binaries."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

root = Path(__file__).resolve().parents[1]
target = root / 'evidence/stock-camera'
target.mkdir(exist_ok=True)
image = Path('/home/ark/sm-t505-port/stock/vendor/vendor.img')
selected = [
    '/lib64/hw/camera.qcom.so', '/lib64/hw/com.qti.chi.override.so',
    '/lib64/camera/com.qti.sensor.n19_hi846_back_txd.so',
    '/lib64/camera/com.qti.sensor.n19_gc5035_front_cxt.so',
    '/etc/camera/camxoverridesettings.txt',
    '/etc/init/android.hardware.camera.provider@2.4-service_64.rc',
]
report = {}
for name in selected:
    output = target / Path(name).name
    subprocess.run(['debugfs', '-R', f'dump {name} "{output}"', str(image)],
                   check=True, capture_output=True, text=True)
    data = output.read_bytes()
    entry = dict(size=len(data), sha256=hashlib.sha256(data).hexdigest())
    if data.startswith(b'\x7fELF'):
        dynamic = subprocess.check_output(['readelf', '-d', str(output)], text=True)
        symbols = subprocess.check_output(['readelf', '--dyn-syms', '--wide', str(output)], text=True)
        entry['needed'] = re.findall(r'\(NEEDED\).*\[(.*?)\]', dynamic)
        entry['exported_entry_points'] = [line.strip() for line in symbols.splitlines()
            if re.search(r'\b(HMI|CHIEntry|CamxEntry|GetCamera.*|GetSensor.*)\b', line)]
        (target/(output.name + '.symbols')).write_text(symbols)
    else:
        entry['text'] = data.decode()
    report[name] = entry
    print(name + ': ' + str(len(data)) + ' bytes')
(target/'dependencies.json').write_text(json.dumps(report, indent=2) + '\n')
print('Saved stock camera dependencies and entry points; no Android binaries executed')
