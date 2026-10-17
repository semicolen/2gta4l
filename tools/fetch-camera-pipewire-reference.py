#!/usr/bin/env python3
"""Fetch versioned primary references for the native PipeWire camera bridge."""
from pathlib import Path
import hashlib,json,urllib.request
workspace=Path(__file__).resolve().parents[1]
out=workspace/'downloads/camera-pipewire-reference';out.mkdir(parents=True,exist_ok=True)
items={
    'pipewire-video-src.c':'https://raw.githubusercontent.com/PipeWire/pipewire/1.6.9/src/examples/video-src.c',
    'snapshot-camera.rs':'https://raw.githubusercontent.com/GNOME/snapshot/51.0/aperture/src/camera.rs',
    'snapshot-device-provider.rs':'https://raw.githubusercontent.com/GNOME/snapshot/51.0/aperture/src/device_provider.rs',
    'snapshot-lib.rs':'https://raw.githubusercontent.com/GNOME/snapshot/51.0/aperture/src/lib.rs',
    'snapshot-viewfinder.rs':'https://raw.githubusercontent.com/GNOME/snapshot/51.0/aperture/src/viewfinder.rs',
    'snapshot-window.rs':None,
    'snapshot-camera-widget.rs':None,
    'gstpipewiresrc.c':'https://raw.githubusercontent.com/PipeWire/pipewire/1.6.9/src/gst/gstpipewiresrc.c',
}
for name,url in items.items():
    if name in ('snapshot-window.rs','snapshot-camera-widget.rs'):
        tree=json.load(urllib.request.urlopen('https://api.github.com/repos/GNOME/snapshot/git/trees/51.0?recursive=1',timeout=30))
        suffixes=('/window.rs','/window/imp.rs') if name=='snapshot-window.rs' else ('/widgets/camera.rs','/widgets/camera/mod.rs')
        candidates=[item['path'] for item in tree['tree'] if item['path'].endswith(suffixes)]
        assert len(candidates)==1,candidates
        url='https://raw.githubusercontent.com/GNOME/snapshot/51.0/'+candidates[0]
    elif (out/name).exists():continue
    data=urllib.request.urlopen(url,timeout=30).read(512*1024)
    assert data and not data.lstrip().startswith(b'<!DOCTYPE')
    (out/name).write_bytes(data)
    print(name,len(data),hashlib.sha256(data).hexdigest(),flush=True)
