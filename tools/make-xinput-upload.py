from pathlib import Path
import base64
import hashlib

binary = Path('artifacts/xinput-aarch64').read_bytes()
digest = hashlib.sha256(binary).hexdigest()
command = "stty -echo\nprintf '\\nGTA4L_XINPUT_BEGIN\\n'\nbase64 -d > /tmp/xinput <<'GTA4L_BINARY_END'\n"
command += base64.encodebytes(binary).decode('ascii') + 'GTA4L_BINARY_END\n'
command += f"printf '%s\\n' '{digest}  /tmp/xinput' | sha256sum -c -\nchmod 700 /tmp/xinput\n"
command += """export DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0
/tmp/xinput list
for id in $(/tmp/xinput list --id-only); do echo "INPUT ID $id"; /tmp/xinput list-props "$id"; done
printf '\\nGTA4L_XINPUT_END\\n'
stty echo
"""
Path('artifacts/live-upload-xinput.sh').write_text(command, newline='\n')
print(f'Prepared xinput upload: {len(binary)} bytes')
