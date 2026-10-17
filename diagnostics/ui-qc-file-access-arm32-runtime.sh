#!/bin/sh
set -eu
grep -q '#11-postmarketOS' /proc/version
python3 - <<'PY'
from pathlib import Path
import hashlib,os,subprocess
assert os.getuid()==10000
test=Path('/tmp/gta4l-upload/faccessat2-arm32-test')
assert hashlib.sha256(test.read_bytes()).hexdigest()=='038f8dccfb441e84733d9247808f6cd4450ad2735ba7044a26f9619646641e8e'
test.chmod(0o700)
result=subprocess.run([str(test)],check=True,capture_output=True,text=True,timeout=10)
assert result.stdout=='ARM32_FACCESSAT2_COMPAT_PASS\n'
print(result.stdout,end='',flush=True)
PY
