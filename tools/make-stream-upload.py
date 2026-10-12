#!/usr/bin/env python3
"""Create a RAM-only console upload with a verified binary checksum."""
from pathlib import Path
import base64
import hashlib

binary = Path('artifacts/gta4l-kmsg-stream').read_bytes()
digest = hashlib.sha256(binary).hexdigest()
encoded = base64.encodebytes(binary).decode('ascii')
command = """stty -echo
printf '\\nGTA4L_STATIC_SETUP_BEGIN\\n'
base64 -d > /tmp/gta4l-kmsg-stream <<'GTA4L_BINARY_END'
""" + encoded + """GTA4L_BINARY_END
(set -eu
""" + f"printf '%s\\n' '{digest}  /tmp/gta4l-kmsg-stream' | sha256sum -c -\n" + """chmod 700 /tmp/gta4l-kmsg-stream
/tmp/gta4l-kmsg-stream </dev/null >/tmp/gta4l-kmsg-stream.log 2>&1 &
echo "Kernel stream PID: $!"
)
printf '\\nGTA4L_STATIC_SETUP_END\\n'
stty echo
"""
Path('artifacts/live-upload-stream.sh').write_text(command, encoding='ascii', newline='\n')
print(f'Prepared {len(binary)} binary bytes; sha256={digest}')
