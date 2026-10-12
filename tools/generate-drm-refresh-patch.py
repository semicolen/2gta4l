#!/usr/bin/env python3
from pathlib import Path
import difflib

source = Path('/home/pmos/sm-t505-port/kernel/drivers/gpu/drm/drm_modes.c').read_text()
needle = '\tout->status = drm_mode_validate_driver(dev, out);'
assert source.count(needle) == 1
replacement = (
    '\t/* Downstream DSI validation consumes the cached refresh field, while\n'
    '\t * standard DRM clients may leave it zero. Derive it from the timings\n'
    '\t * before asking the vendor driver to validate the requested mode. */\n'
    '\tif (!out->vrefresh)\n'
    '\t\tout->vrefresh = drm_mode_vrefresh(out);\n\n' + needle
)
patched = source.replace(needle, replacement)
diff = ''.join(difflib.unified_diff(source.splitlines(True), patched.splitlines(True),
    fromfile='a/drivers/gpu/drm/drm_modes.c', tofile='b/drivers/gpu/drm/drm_modes.c'))
target = Path('/mnt/c/postmarketOS-gta4l/port/linux-samsung-gta4l/cache-drm-refresh.patch')
target.write_text(diff, newline='\n')
print('Generated exact source patch for DRM refresh caching')
