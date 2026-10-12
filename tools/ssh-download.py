#!/usr/bin/env python3
"""Retrieve a named diagnostic artifact using the tablet's pinned SSH host key."""
import argparse
from pathlib import Path
import re
import paramiko

parser = argparse.ArgumentParser()
parser.add_argument('remote')
parser.add_argument('local', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
local = args.local.resolve()
assert local.is_relative_to(root/'evidence') or local.is_relative_to(root/'artifacts')
login = (root/'artifacts/initial-login.txt').read_text()
user = re.search(r'^User: (.+)$', login, re.M).group(1)
password = re.search(r'^Password: (.+)$', login, re.M).group(1)
client = paramiko.SSHClient()
client.load_host_keys(str(root/'artifacts/ssh-known-hosts'))
client.set_missing_host_key_policy(paramiko.RejectPolicy())
try:
    client.connect('172.16.42.1', username=user, password=password,
                   look_for_keys=False, allow_agent=False, timeout=5)
    with client.open_sftp() as sftp:
        assert sftp.stat(args.remote).st_size < 32*1024*1024
        local.parent.mkdir(parents=True, exist_ok=True)
        sftp.get(args.remote, str(local))
        print(f'Retrieved {local.name}: {local.stat().st_size} bytes')
finally:
    client.close()
