"""Generate a hash-guarded update for only the isolated camera test helper."""
from pathlib import Path
import hashlib

root = Path(__file__).resolve().parents[1]
digest = hashlib.sha256((root/'artifacts/camera-development/camera-hal-enumerate').read_bytes()).hexdigest()
script = (root/'tools/live-update-camera-enumerator.sh').read_text()
import re
script = re.sub(r"[0-9a-f]{64}(  /tmp/gta4l-upload/camera-hal-enumerate)", digest+r'\1', script)
(root/'tools/live-update-camera-enumerator.sh').write_text(script, newline='\n')
script = (root/'tools/live-camera-hal-enumerate.sh').read_text()
script = script.replace('--enumerate', '--open-check')
(root/'tools/live-camera-hal-open-check.sh').write_text(script, newline='\n')
script = (root/'tools/live-camera-hal-enumerate.sh').read_text().replace('--enumerate', '--stream-check')
(root/'tools/live-camera-hal-stream-check.sh').write_text(script, newline='\n')
script = (root/'tools/live-camera-hal-enumerate.sh').read_text().replace('--enumerate', '--allocator-check')
(root/'tools/live-camera-allocator-check.sh').write_text(script, newline='\n')
print('Prepared isolated diagnostic update with SHA256 '+digest)
for option in ('buffer-check', 'capture-check', 'front-capture-check','stream-capabilities','full-capture-check','front-full-capture-check','color-capture-check','front-color-capture-check'):
    script = (root/'tools/live-camera-hal-enumerate.sh').read_text().replace('--enumerate', '--'+option)
    if 'full-capture' in option: script=script.replace('timeout 25','timeout 35')
    (root/('tools/live-camera-'+option+'.sh')).write_text(script, newline='\n')
