"""Save pinned official Android 12 ABI references for camera development."""
from pathlib import Path
import base64
import hashlib
import json
import urllib.request

root = Path(__file__).resolve().parents[1]
out = root/'evidence/camera-aosp'
out.mkdir(exist_ok=True)
sources = {
    'hardware.h': ('hardware/libhardware', 'include/hardware/hardware.h'),
    'camera_common.h': ('hardware/libhardware', 'include/hardware/camera_common.h'),
    'camera3.h': ('hardware/libhardware', 'include/hardware/camera3.h'),
    'gralloc.h': ('hardware/libhardware', 'include/hardware/gralloc.h'),
    'gralloc1.h': ('hardware/libhardware', 'include/hardware/gralloc1.h'),
    'graphics.h': ('system/core', 'libsystem/include/system/graphics.h'),
    'camera_metadata.h': ('system/media', 'camera/include/system/camera_metadata.h'),
    'camera_metadata_tags.h': ('system/media', 'camera/include/system/camera_metadata_tags.h'),
    'crtbegin.c': ('bionic', 'libc/arch-common/bionic/crtbegin.c'),
    'libc_init_common.h': ('bionic', 'libc/bionic/libc_init_common.h'),
}
manifest = {}
for name, (repo, path) in sources.items():
    url = f'https://android.googlesource.com/platform/{repo}/+/refs/tags/android-12.0.0_r1/{path}?format=TEXT'
    data = base64.b64decode(urllib.request.urlopen(url, timeout=25).read())
    (out/name).write_bytes(data)
    manifest[name] = dict(url=url, sha256=hashlib.sha256(data).hexdigest())
(out/'sources.json').write_text(json.dumps(manifest, indent=2)+'\n')
print('Saved official Android 12 camera/startup ABI references and hashes')
