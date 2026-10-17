"""Package matching stock userspace; helper is compiled from source by abuild."""
from pathlib import Path
import hashlib,json,shutil,tarfile
root=Path(__file__).resolve().parents[1]
runtime=Path('/home/ark/sm-t505-port/camera-development/runtime-root')
out=root/'firmware-local'
archive=out/'gta4l-camera-runtime-T505XXS8CXG1.tar.gz'
files={}
with tarfile.open(archive,'w:gz',compresslevel=3) as tar:
    for path in sorted(runtime.rglob('*')):
        relative=path.relative_to(runtime)
        if path.is_symlink() or not path.is_file() or 'lib' in relative.parts: continue
        if relative.parts[:2]==('system','bin'): continue
        data=path.read_bytes()
        files[str(relative)]=dict(size=len(data),sha256=hashlib.sha256(data).hexdigest())
        tar.add(path,arcname=str(relative),recursive=False)
for name in ('camera-hal-enumerate.c','camera-buffer.h'):
    shutil.copyfile(root/'tools'/name,root/'port/camera-gta4l'/name)
manifest=dict(stock_version='T505XXS8CXG1',archive=archive.name,
    sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),files=files,
    helper_built_by_apkbuild=True)
(root/'artifacts/camera-development/package-runtime.json').write_text(json.dumps(manifest,indent=2)+'\n')
shutil.copyfile(archive,root/'port/camera-gta4l'/archive.name)
print('Prepared camera APK source archive: '+str(archive.stat().st_size)+' bytes; '+str(len(files))+' files')
