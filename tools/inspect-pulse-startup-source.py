#!/usr/bin/env python3
"""Save official PulseAudio 17.0 source for the downstream timing audit."""
from pathlib import Path
import hashlib,io,tarfile,urllib.request
root=Path('/home/ark/sm-t505-port/sources/pulseaudio-startup-audit')
root.mkdir(parents=True,exist_ok=True)
archive=root/'pulseaudio-v17.0.tar.bz2'
if not archive.exists():
    request=urllib.request.Request('https://gitlab.freedesktop.org/pulseaudio/pulseaudio/-/archive/v17.0/pulseaudio-v17.0.tar.bz2',headers={'User-Agent':'gta4l-audio-audit'})
    with urllib.request.urlopen(request,timeout=25) as response:data=response.read(12*1024*1024)
    archive.write_bytes(data)
data=archive.read_bytes()
with tarfile.open(fileobj=io.BytesIO(data),mode='r:bz2') as tar:
    for member in tar.getmembers():
        relative=Path(*Path(member.name).parts[1:])
        if member.isfile() and relative.suffix in ('.c','.h','.in') and relative.parts and relative.parts[0]=='src':
            if '..' in relative.parts:raise SystemExit('Invalid archive path')
            target=root/relative;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(tar.extractfile(member).read())
print('Official PulseAudio v17.0 source archived; SHA256='+hashlib.sha256(data).hexdigest())
