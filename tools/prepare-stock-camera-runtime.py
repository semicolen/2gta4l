"""Build a private stock camera runtime tree from local images, without execution."""
from pathlib import Path
import hashlib
import json
import re
import struct
import subprocess
import zipfile

base = Path('/home/ark/sm-t505-port')
work = base/'camera-development'
runtime = work/'runtime-root'
runtime.mkdir(parents=True, exist_ok=True)
vendor = base/'stock/vendor/vendor.img'
raw = base/'stock/vendor/super.raw.img'
workspace = Path(__file__).resolve().parents[1]
loop_devices = []

def debug(image, command):
    return subprocess.run(['debugfs', '-R', command, str(image)], check=True,
                          capture_output=True, text=True).stdout

def names(image, directory):
    result = {}
    for line in debug(image, 'ls -p '+directory).splitlines():
        fields = line.split('/')
        if len(fields) >= 7 and fields[5] not in ('.', '..'):
            result[fields[5]] = fields[2]
    return result

def dump(image, source, output):
    output.parent.mkdir(parents=True, exist_ok=True)
    debug(image, f'dump {source} "{output}"')
    if not output.exists() or not output.stat().st_size:
        raise RuntimeError('Stock file extraction failed: '+source)

def map_system():
    with raw.open('rb') as stream:
        stream.seek(12288)
        initial = stream.read(128)
        magic, major, minor, size = struct.unpack_from('<IHHI', initial)
        assert magic == 0x414c5030 and major == 10
        stream.seek(12288)
        header = bytearray(stream.read(size))
        expected = bytes(header[12:44])
        header[12:44] = bytes(32)
        assert hashlib.sha256(header).digest() == expected
        tables = stream.read(struct.unpack_from('<I', header, 44)[0])
        assert hashlib.sha256(tables).digest() == header[48:80]
        po, pn, ps = struct.unpack_from('<III', header, 80)
        eo, en, es = struct.unpack_from('<III', header, 92)
        for i in range(pn):
            rec = tables[po+i*ps:po+(i+1)*ps]
            if rec[:36].split(b'\0')[0] != b'system': continue
            _, first, count, _ = struct.unpack_from('<IIII', rec, 36)
            assert count == 1 and first < en
            sectors, typ, sector, source = struct.unpack_from('<QIQI', tables, eo+first*es)
            assert typ == 0 and source == 0
            assert (sector+sectors)*512 <= raw.stat().st_size
            device = subprocess.check_output(['losetup', '--find', '--show', '--read-only',
                '--offset', str(sector*512), '--sizelimit', str(sectors*512), str(raw)], text=True).strip()
            loop_devices.append(device)
            return device
        raise RuntimeError('System logical partition not found')

def extract_apex(system, name, target_name):
    archive = work/(name+'.apex')
    payload = work/(name+'.img')
    if not archive.exists(): dump(system, '/system/apex/'+name+'.apex', archive)
    if not payload.exists():
        with zipfile.ZipFile(archive) as z:
            with z.open('apex_payload.img') as src, payload.open('wb') as dst:
                while data := src.read(1024*1024): dst.write(data)
    target = runtime/'apex'/target_name
    target.mkdir(parents=True, exist_ok=True)
    debug(payload, f'rdump / "{target}"')
    return target

try:
    system = map_system()
    bionic = extract_apex(system, 'com.android.runtime', 'com.android.runtime')
    vndk = extract_apex(system, 'com.android.vndk.current', 'com.android.vndk.v31')
    for directory in ['vendor/lib64', 'vendor/lib64/hw', 'system/lib64', 'system/bin',
                      'vendor/etc/camera', 'data/vendor/camera', 'data/misc/camera',
                      'dev', 'proc', 'sys', 'tmp', 'linkerconfig']:
        (runtime/directory).mkdir(parents=True, exist_ok=True)
    # Only 64-bit camera plugins and sensor/tuning data; no Android init/services.
    debug(vendor, f'rdump /lib64/camera "{runtime / "vendor/lib64"}"')
    dump(vendor, '/etc/camera/camxoverridesettings.txt', runtime/'vendor/etc/camera/camxoverridesettings.txt')
    vend_names = names(vendor, '/lib64')
    sys_names = names(system, '/system/lib64')
    seeds = ['hw/camera.qcom.so', 'hw/com.qti.chi.override.so', 'hw/gralloc.bengal.so']
    seeds += [n for n in ['com.qti.chiusecaseselector.so', 'libqti-perfd-client.so',
        'libthermalclient.so', 'libllvm-qcom.so', 'libCB.so', 'libopestriping.so'] if n in vend_names]
    seeds += [n for n in vend_names if n.endswith('.so') and n.startswith(('libcamx','libmmcamera'))]
    for name in seeds:
        dump(vendor, '/lib64/'+name, runtime/'vendor/lib64'/name)
    queue = list((runtime/'vendor/lib64').rglob('*.so'))
    done = set()
    report = {}
    missing = set()
    while queue:
        path = queue.pop()
        if path in done: continue
        done.add(path)
        assert len(done) <= 300, 'Unexpectedly large camera dependency closure'
        if not path.read_bytes().startswith(b'\x7fELF'): continue
        dynamic = subprocess.check_output(['readelf', '-d', str(path)], text=True)
        needed = re.findall(r'\(NEEDED\).*\[(.*?)\]', dynamic)
        report[str(path.relative_to(runtime))] = dict(
            sha256=hashlib.sha256(path.read_bytes()).hexdigest(), needed=needed)
        for name in needed:
            assert '/' not in name and name.endswith('.so'), name
            candidates = [bionic/'lib64/bionic'/name, runtime/'vendor/lib64'/name,
                          runtime/'vendor/lib64/hw'/name,
                          vndk/'lib64'/name, runtime/'system/lib64'/name]
            existing = next((p for p in candidates if p.is_file()), None)
            if existing: queue.append(existing); continue
            if name in vend_names:
                output = runtime/'vendor/lib64'/name
                dump(vendor, '/lib64/'+name, output)
            elif name in sys_names and sys_names[name].startswith('100'):
                output = runtime/'system/lib64'/name
                dump(system, '/system/lib64/'+name, output)
            else:
                missing.add(name)
                continue
            queue.append(output)
    (runtime/'system/bin/linker64').write_bytes((bionic/'bin/linker64').read_bytes())
    (runtime/'system/bin/linker64').chmod(0o755)
    result = dict(runtime=str(runtime), libraries=report, missing=sorted(missing))
    (workspace/'evidence/stock-camera/runtime-dependencies.json').write_text(json.dumps(result, indent=2)+'\n')
    print('Camera runtime ELF objects inspected='+str(len(report)))
    print('Unresolved dependency names='+','.join(sorted(missing)))
    print('Runtime prepared from matching local stock firmware; no binaries executed')
    if missing: raise SystemExit(1)
finally:
    for device in reversed(loop_devices):
        subprocess.run(['losetup', '--detach', device], check=True)
