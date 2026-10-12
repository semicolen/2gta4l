#!/usr/bin/env python3
from pathlib import Path
import base64
import hashlib
data = Path('artifacts/runtime-gdb.tar.gz').read_bytes()
digest = hashlib.sha256(data).hexdigest()
command = "stty -echo\nprintf '\\nGTA4L_GDB_SETUP_BEGIN\\n'\nbase64 -d > /tmp/gta4l-gdb.tar.gz <<'GTA4L_GDB_DATA'\n"
command += base64.encodebytes(data).decode('ascii') + 'GTA4L_GDB_DATA\n'
command += f"(set -eu\nprintf '%s\\n' '{digest}  /tmp/gta4l-gdb.tar.gz' | sha256sum -c -\n"
command += "mkdir -p /tmp/gta4l-gdb\ntar -xzf /tmp/gta4l-gdb.tar.gz -C /tmp/gta4l-gdb\nLD_LIBRARY_PATH=/tmp/gta4l-gdb/lib /tmp/gta4l-gdb/bin/gdb --version | head -3\n)\n"
command += "printf '\\nGTA4L_GDB_SETUP_END\\n'\nstty echo\n"
Path('artifacts/live-upload-gdb.sh').write_text(command, newline='\n')
print(f'Prepared {len(data)} RAM debugger bytes; sha256={digest}')
