#!/usr/bin/env python3
"""Pin a fresh image's SSH public keys from recovery before its first boot."""
import argparse
import json
from pathlib import Path
import subprocess
import paramiko

parser = argparse.ArgumentParser()
parser.add_argument('--serial', required=True)
parser.add_argument('--ui', required=True, choices=[
    'xfce4', 'plasma-mobile', 'plasma-desktop', 'gnome-mobile', 'gnome', 'sxmo-de-sway'])
args = parser.parse_args()
workspace = Path(__file__).resolve().parents[1]
ui_dir = workspace / 'evidence/ui-qc' / args.ui
stamp = (ui_dir / 'latest-attempt.txt').read_text().strip()
out = ui_dir / stamp
report = json.loads((out / 'installation.json').read_text())
assert report['ui'] == args.ui and report['installer_completed']
assert report['boot_readback_matches'] and report['recovery_unchanged']
profile = next(p for p in json.loads((workspace / 'artifacts/ui-builds/index.json').read_text())['profiles']
               if p['ui'] == args.ui)
records = {}
for section in (out / 'installed-packages.txt').read_text().split('\n\n'):
    fields = dict(line.split(':', 1) for line in section.splitlines() if ':' in line)
    if 'P' in fields:
        records[fields['P']] = fields['V']
assert all(records.get(k) == v for k, v in profile['selected_packages'].items())
adb = ['adb', '-s', args.serial]
root = '/tmp/postmarketos/chroot/mnt/pmOS'

def run(*command):
    return subprocess.run(adb + list(command), capture_output=True, timeout=30, check=True).stdout

assert run('get-state').strip() == b'recovery'
assert run('shell', 'getprop', 'ro.product.device').strip() == b'gta4l'
assert run('shell', 'getprop', 'ro.bootloader').strip().startswith(b'T505')
# The freshly extracted /dev is empty until normal init mounts devtmpfs.
run('shell', 'mount', '--bind', '/dev', root + '/dev')
try:
    (out / 'ssh-keygen.log').write_bytes(run('shell', 'chroot', root, '/usr/bin/ssh-keygen', '-A'))
finally:
    run('shell', 'umount', root + '/dev')
keys = paramiko.HostKeys()
for name in ('ssh_host_ed25519_key.pub', 'ssh_host_ecdsa_key.pub', 'ssh_host_rsa_key.pub'):
    content = run('exec-out', 'cat', root + '/etc/ssh/' + name)
    (out / name).write_bytes(content)
    fields = content.decode().split()
    entry = paramiko.hostkeys.HostKeyEntry.from_line('172.16.42.1 ' + fields[0] + ' ' + fields[1])
    keys.add('172.16.42.1', entry.key.get_name(), entry.key)
hosts = workspace / 'artifacts/ssh-known-hosts'
if hosts.exists():
    prior = out / 'ssh-known-hosts-before'
    if not prior.exists():
        prior.write_bytes(hosts.read_bytes())
keys.save(str(hosts))
report['ssh_host_keys_generated_and_pinned_in_recovery'] = True
report['installed_port_packages_match'] = True
(out / 'installation.json').write_text(json.dumps(report, indent=2) + '\n')
print('Installed port packages match; fresh SSH public keys pinned through recovery')
