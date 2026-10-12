#!/usr/bin/env python3
"""Run a workspace diagnostic through authenticated tablet SSH."""
from pathlib import Path
import argparse
import re
import shlex
import time
import paramiko

parser = argparse.ArgumentParser()
parser.add_argument('command', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--user', action='store_true', help='Run as tablet instead of sudo root')
parser.add_argument('--timeout', type=int, default=40, help='Bound total diagnostic time in seconds (1–120)')
args = parser.parse_args()
if not 1 <= args.timeout <= 120:
    parser.error('--timeout must be between 1 and 120 seconds')
workspace = Path(__file__).resolve().parents[1]
login = (workspace / 'artifacts/initial-login.txt').read_text()
username = re.search(r'^User: (.+)$', login, re.M).group(1)
password = re.search(r'^Password: (.+)$', login, re.M).group(1)
hosts = workspace / 'artifacts/ssh-known-hosts'
client = paramiko.SSHClient()
if hosts.exists():
    client.load_host_keys(str(hosts))
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    client.connect('172.16.42.1', username=username, password=password,
                   look_for_keys=False, allow_agent=False, timeout=4,
                   auth_timeout=8, banner_timeout=8)
    client.save_host_keys(str(hosts))
    command = '/bin/sh -c ' + shlex.quote(args.command.read_text())
    if not args.user:
        command = "sudo -S -p '' " + command
    stdin, stdout, stderr = client.exec_command(command, timeout=30)
    if not args.user:
        stdin.write(password + '\n')
        stdin.flush()
    stdin.channel.shutdown_write()
    # Vendor proc attributes can stream forever. Bound both time and saved
    # output, and drain stderr alongside stdout to avoid a channel deadlock.
    channel = stdout.channel
    deadline = time.monotonic() + args.timeout
    chunks = []
    saved = 0
    total = 0
    limit = 2 * 1024 * 1024
    timed_out = False
    while True:
        for ready, receive in [(channel.recv_ready, channel.recv),
                               (channel.recv_stderr_ready, channel.recv_stderr)]:
            if ready():
                data = receive(65536)
                total += len(data)
                keep = data[:max(0, limit - saved)]
                chunks.append(keep)
                saved += len(keep)
        if channel.exit_status_ready() and not channel.recv_ready() and not channel.recv_stderr_ready():
            break
        if time.monotonic() >= deadline:
            timed_out = True
            channel.close()
            break
        time.sleep(0.01)
    output = b''.join(chunks)
    if total > limit:
        output += f'\n[Truncated: received {total} bytes, saved first {limit}]\n'.encode()
    if timed_out:
        output += f'\n[Diagnostic exceeded {args.timeout} seconds; SSH channel closed]\n'.encode()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(output)
    status = 124 if timed_out else channel.recv_exit_status()
    print(f'Saved {len(output)} SSH console bytes; exit status {status}')
    if status:
        raise SystemExit(status)
finally:
    client.close()
