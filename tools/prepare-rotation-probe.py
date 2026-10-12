from pathlib import Path
import hashlib
import tarfile

root = Path(__file__).resolve().parents[1]
package = root / 'artifacts/apks/libssc-0.4.4-r0.apk'
with tarfile.open(package) as archive:
    print(archive.extractfile('.PKGINFO').read().decode())
digest = hashlib.sha256(package.read_bytes()).hexdigest()
script = f'''#!/bin/sh
set -eu
cd /tmp/gta4l-upload
printf '%s\\n' '{digest}  {package.name}' | sha256sum -c -
apk --no-interactive --allow-untrusted add ./{package.name}
timeout 25 ssccli --sensor=accelerometer --timeout=5 --debug
echo SSC_ACCELEROMETER_PROBE_END
'''
(root / 'tools/live-ssc-probe.sh').write_text(script, newline='\n')
