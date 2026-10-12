#!/usr/bin/env python3
"""Upload diagnostic files to the tablet's temporary directory over SSH."""
from pathlib import Path
import argparse
import hashlib
import re
import paramiko

parser = argparse.ArgumentParser()
parser.add_argument('files', type=Path, nargs='+')
args = parser.parse_args()
workspace = Path(__file__).resolve().parents[1]
login = (workspace / 'artifacts/initial-login.txt').read_text()
username = re.search(r'^User: (.+)$', login, re.M).group(1)
password = re.search(r'^Password: (.+)$', login, re.M).group(1)
hosts = workspace / 'artifacts/ssh-known-hosts'
client = paramiko.SSHClient()
client.load_host_keys(str(hosts))
client.set_missing_host_key_policy(paramiko.RejectPolicy())
try:
    client.connect('172.16.42.1', username=username, password=password,
                   look_for_keys=False, allow_agent=False, timeout=4,
                   auth_timeout=8, banner_timeout=8)
    with client.open_sftp() as sftp:
        directory = '/tmp/gta4l-upload'
        try:
            sftp.mkdir(directory, mode=0o700)
        except OSError:
            # Check ownership/type through SFTP before reusing the directory.
            import stat
            info = sftp.lstat(directory)
            assert stat.S_ISDIR(info.st_mode) and info.st_uid == 10000
        for path in args.files:
            assert path.is_file()
            remote = directory + '/' + path.name
            sftp.put(str(path), remote)
            sftp.chmod(remote, 0o600)
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            print(f'Uploaded {path.name} ({path.stat().st_size} bytes), SHA256 {digest}')
finally:
    client.close()
