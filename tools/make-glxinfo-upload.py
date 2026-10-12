from pathlib import Path
import base64
import hashlib

binary = Path('artifacts/glxinfo-aarch64').read_bytes()
digest = hashlib.sha256(binary).hexdigest()
command = "stty -echo\nprintf '\\nGTA4L_GLXINFO_BEGIN\\n'\nbase64 -d > /tmp/glxinfo <<'GTA4L_BINARY_END'\n"
command += base64.encodebytes(binary).decode('ascii') + 'GTA4L_BINARY_END\n'
command += f"printf '%s\\n' '{digest}  /tmp/glxinfo' | sha256sum -c -\nchmod 700 /tmp/glxinfo\n"
command += """export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
/tmp/glxinfo -B
printf '\\nGTA4L_GLXINFO_END\\n'
stty echo
"""
Path('artifacts/live-upload-glxinfo.sh').write_text(command, newline='\n')
print(f'Prepared glxinfo upload: {len(binary)} bytes')
