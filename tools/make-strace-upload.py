#!/usr/bin/env python3
from pathlib import Path
import base64
import hashlib

bundle = Path('artifacts/runtime-strace.tar.gz').read_bytes()
digest = hashlib.sha256(bundle).hexdigest()
command = """stty -echo
printf '\\nGTA4L_TRACE_SETUP_BEGIN\\n'
base64 -d > /tmp/gta4l-trace.tar.gz <<'GTA4L_BUNDLE_END'
""" + base64.encodebytes(bundle).decode('ascii') + """GTA4L_BUNDLE_END
(set -eu
""" + f"printf '%s\\n' '{digest}  /tmp/gta4l-trace.tar.gz' | sha256sum -c -\n" + """mkdir -p /tmp/gta4l-trace
tar -xzf /tmp/gta4l-trace.tar.gz -C /tmp/gta4l-trace
LD_LIBRARY_PATH=/tmp/gta4l-trace/lib /tmp/gta4l-trace/bin/strace -V
LD_LIBRARY_PATH=/tmp/gta4l-trace/lib /tmp/gta4l-trace/bin/strace -o /tmp/gta4l-trace/test.log /bin/true
cat /tmp/gta4l-trace/test.log
)
printf '\\nGTA4L_TRACE_SETUP_END\\n'
stty echo
"""
Path('artifacts/live-upload-strace.sh').write_text(command, encoding='ascii', newline='\n')
print(f'Prepared {len(bundle)} compressed bytes; sha256={digest}')
