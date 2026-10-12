#!/usr/bin/env python3
from pathlib import Path
import base64
import hashlib

data = Path('artifacts/bwrap-gta4l').read_bytes()
digest = hashlib.sha256(data).hexdigest()
command = """stty -echo
printf '\\nGTA4L_BWRAP_SETUP_BEGIN\\n'
base64 -d > /tmp/bwrap-gta4l <<'GTA4L_BWRAP_END'
""" + base64.encodebytes(data).decode('ascii') + """GTA4L_BWRAP_END
(set -eu
""" + f"printf '%s\\n' '{digest}  /tmp/bwrap-gta4l' | sha256sum -c -\n" + """chmod 755 /tmp/bwrap-gta4l
/tmp/bwrap-gta4l --version
/tmp/bwrap-gta4l --unshare-all --die-with-parent --ro-bind /usr /usr --dev /dev --symlink usr/lib /lib --symlink usr/bin /bin --tmpfs /tmp --chdir / /usr/bin/busybox true
echo 'Compatible Bubblewrap namespace and filesystem test passed'
)
printf '\\nGTA4L_BWRAP_SETUP_END\\n'
stty echo
"""
Path('artifacts/live-upload-bwrap.sh').write_text(command, encoding='ascii', newline='\n')
print(f'Prepared {len(data)} ARM64 bytes; sha256={digest}')
