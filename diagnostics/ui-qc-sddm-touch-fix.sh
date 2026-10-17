#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import pwd
assert os.geteuid() == 0
matrix = '-1,0,1,0,0,-1,1,0,0,0,1,0,0,0,0,1'
text = '[Libinput][0][0][himax-touchscreen]\nCalibrationMatrix=' + matrix + '\n'
for name in ('sddm', 'tablet'):
    account = pwd.getpwnam(name)
    directory = Path(account.pw_dir)/'.config'
    directory.mkdir(mode=0o755, parents=True, exist_ok=True)
    os.chown(directory, account.pw_uid, account.pw_gid)
    target = directory/'kcminputrc'
    backup = Path('/var/lib/gta4l-ui-qc')/(name+'-kcminputrc-before-greeter-fix')
    backup.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if target.exists() and not backup.exists():
        backup.write_bytes(target.read_bytes())
        backup.chmod(0o600)
    # This candidate has no other customized input settings. Preserve unrelated
    # groups if another device has been configured during QC.
    if target.exists():
        import configparser
        config = configparser.RawConfigParser(strict=False)
        config.optionxform = str
        config.read(target)
        section = 'Libinput][0][0][himax-touchscreen'
        if not config.has_section(section): config.add_section(section)
        config.set(section, 'CalibrationMatrix', matrix)
        config.remove_option(section, 'OutputUuid')
        with target.open('w') as stream: config.write(stream, space_around_delimiters=False)
    else:
        target.write_text(text)
    target.chmod(0o644)
    os.chown(target, account.pw_uid, account.pw_gid)
    print('Saved Himax calibration for', name, flush=True)
os.sync()
PY
/sbin/reboot
