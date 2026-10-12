#!/bin/sh
set -eu
printf '%s\n' 'c785f220937932205a1ebf080fec7617444804f91cac3b53d49b9577d0fee30c  /tmp/gta4l-upload/runtime-strace.tar.gz' | sha256sum -c -
mkdir -p /tmp/gta4l-trace
tar -xzf /tmp/gta4l-upload/runtime-strace.tar.gz -C /tmp/gta4l-trace
printf '=== Isolated camera runtime failure diagnostics ===\n'
command -v strace || true
ls -l /dev/binder /dev/hwbinder /dev/vndbinder /dev/ion 2>/dev/null || true
python3 - <<'PY'
from pathlib import Path
import os
import subprocess
root = Path('/opt/gta4l-camera-dev/r0')
env = dict(os.environ, LD_LIBRARY_PATH='/tmp/gta4l-trace/lib:/apex/com.android.runtime/lib64/bionic:/vendor/lib64:/apex/com.android.vndk.v31/lib64:/system/lib64')
trace = root/'runtime-smoke.strace'
if Path('/tmp/gta4l-trace/bin/strace').exists():
    args = ['timeout','10','/tmp/gta4l-trace/bin/strace','-f','-o',str(trace),
            'chroot',str(root),'/system/bin/camera-hal-enumerate','--smoke']
    p = subprocess.run(args, env=env, capture_output=True, text=True)
    print('trace_exit='+str(p.returncode))
    print(p.stdout)
    print(p.stderr)
    lines = trace.read_text(errors='replace').splitlines()
    print('\n'.join(lines[-60:]))
else:
    print('strace unavailable')
PY
printf 'CAMERA_RUNTIME_DIAGNOSE_END\n'
