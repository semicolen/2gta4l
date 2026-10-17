#!/usr/bin/env python3
"""Sideload one verified clean UI candidate; retain recovery for inspection."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
from datetime import datetime, timezone

parser = argparse.ArgumentParser()
parser.add_argument('--serial', required=True)
parser.add_argument('--ui', required=True, choices=[
    'xfce4', 'plasma-mobile', 'plasma-desktop', 'gnome-mobile', 'gnome', 'sxmo-de-sway'])
parser.add_argument('--verify-attempt', type=Path, help='Verify an existing recovery install without flashing again')
args = parser.parse_args()
workspace = Path(__file__).resolve().parents[1]
adb = ['adb', '-s', args.serial]
profile = next(p for p in json.loads((workspace / 'artifacts/ui-builds/index.json').read_text())['profiles']
               if p['ui'] == args.ui)
backup_dir = workspace / 'artifacts/backups/ui-qc-working-system'
backup = json.loads((backup_dir / 'manifest.json').read_text())
assert backup['verified_complete'] and backup['partitions']['userdata']['device_hash_matches']
assert (backup_dir / 'userdata.img').stat().st_size == backup['partitions']['userdata']['bytes']
assert backup['serial'] == args.serial and backup['device'] == 'SM-T505'
package = workspace / 'artifacts/ui-builds' / profile['package']
assert package.stat().st_size == profile['bytes']
with package.open('rb') as stream:
    assert hashlib.file_digest(stream, 'sha256').hexdigest() == profile['sha256']
stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
if args.verify_attempt:
    out = args.verify_attempt.resolve()
    assert out.parent == (workspace / 'evidence/ui-qc' / args.ui).resolve()
    assert (out / 'pmos.log').is_file() and (out / 'adb-sideload.log').is_file()
    stamp = out.name
else:
    out = workspace / 'evidence/ui-qc' / args.ui / stamp
    out.mkdir(parents=True, exist_ok=False)

def run(*command, timeout=30):
    return subprocess.run(adb + list(command), capture_output=True, check=True, timeout=timeout).stdout

def query(*command):
    return run('shell', *command).decode().strip()

def device_state():
    result = subprocess.run(adb + ['get-state'], capture_output=True, timeout=5)
    return result.stdout.decode().strip()

def recovery_hash():
    content = run('exec-out', 'cat', '/dev/block/by-name/recovery', timeout=90)
    assert len(content) == backup['partitions']['recovery']['bytes']
    return hashlib.sha256(content).hexdigest()

assert device_state() == 'recovery'
assert query('id', '-u') == '0'
assert query('getprop', 'ro.product.device') == 'gta4l'
assert query('getprop', 'ro.bootloader').startswith('T505')
assert query('readlink', '-f', '/dev/block/by-name/boot') == '/dev/block/mmcblk0p69'
assert query('readlink', '-f', '/dev/block/by-name/userdata') == '/dev/block/mmcblk0p80'
assert query('blockdev', '--getsize64', '/dev/block/by-name/boot') == '100663296'
assert query('blockdev', '--getsize64', '/dev/block/by-name/userdata') == '23484415488'
assert int(query('cat', '/sys/class/power_supply/battery/capacity')) >= 25
before_recovery = recovery_hash()
assert before_recovery == backup['partitions']['recovery']['sha256']
if not args.verify_attempt:
    (out / 'mounts-before.txt').write_bytes(run('shell', 'cat', '/proc/mounts'))
    print('Candidate and offline backup verified; starting OrangeFox sideload for ' + args.ui, flush=True)

def install():
  with (out / 'orangefox-sideload-cli.log').open('wb') as cli_log:
    cli = subprocess.Popen(adb + ['shell', 'twrp', 'sideload'], stdout=cli_log, stderr=subprocess.STDOUT)
    deadline = time.monotonic() + 90
    while device_state() != 'sideload':
        if time.monotonic() >= deadline:
            cli.terminate()
            raise RuntimeError('OrangeFox did not enter sideload; no ZIP was sent. Evidence: ' + str(out))
        time.sleep(2)
    with (out / 'adb-sideload.log').open('wb') as transfer_log:
        transfer = subprocess.Popen(adb + ['sideload', str(package)], stdout=transfer_log,
                                    stderr=subprocess.STDOUT)
        transfer_start = time.monotonic()
        deadline = transfer_start + 2400
        while transfer.poll() is None:
            if time.monotonic() >= deadline:
                transfer.terminate()
                raise RuntimeError('Sideload exceeded 40 minutes; stay in recovery and inspect logs')
            print('OrangeFox installation active; ' + str(round(time.monotonic() - transfer_start))
                  + ' seconds elapsed', flush=True)
            time.sleep(20)
        sideload_status = transfer.returncode
    # ADB may report a nonzero status at 47% despite a successful recovery install.
    # The installer log and readback below determine the outcome.
    deadline = time.monotonic() + 120
    while device_state() != 'recovery':
        if time.monotonic() >= deadline:
            raise RuntimeError('Recovery ADB did not return; do not reboot before checking installation')
        time.sleep(2)
    if cli.poll() is None:
        try:
            cli.wait(timeout=10)
        except subprocess.TimeoutExpired:
            cli.terminate()
  return sideload_status

if args.verify_attempt:
    result_path = out / 'sideload-result.json'
    sideload_status = json.loads(result_path.read_text())['exit_status'] if result_path.exists() else None
else:
    sideload_status = install()
    (out / 'sideload-result.json').write_text(json.dumps({'exit_status': sideload_status}) + '\n')
time.sleep(2)

for source, name in [('/tmp/recovery.log', 'recovery.log'),
                     ('/tmp/postmarketos/pmos.log', 'pmos.log'),
                     ('/tmp/postmarketos/preflight.log', 'preflight.log')]:
    run('pull', source, str(out / name))
pmos_log = (out / 'pmos.log').read_text(errors='replace')
assert 'Installation done.' in pmos_log, 'Installer did not finish; inspect ' + str(out)
assert 'Flashing boot.img...' in pmos_log
for attempt in range(3):
    boot = run('exec-out', 'head', '-c', str(profile['boot_bytes']), '/dev/block/by-name/boot', timeout=90)
    (out / ('boot-readback-' + str(attempt) + '.json')).write_text(json.dumps({
        'bytes': len(boot), 'sha256': hashlib.sha256(boot).hexdigest()}) + '\n')
    if len(boot) == profile['boot_bytes']:
        break
    time.sleep(2)
assert len(boot) == profile['boot_bytes'], 'Incomplete ADB readback; stay in recovery'
boot_hash = hashlib.sha256(boot).hexdigest()
assert boot_hash == profile['boot_sha256'], 'Boot readback differs; stay in recovery'
after_recovery = recovery_hash()
assert after_recovery == before_recovery, 'Recovery changed; stay in recovery'
root = '/tmp/postmarketos/chroot/mnt/pmOS'
(out / 'installed-packages.txt').write_bytes(run('shell', 'cat', root + '/lib/apk/db/installed'))
for key in ('ssh_host_ed25519_key.pub', 'ssh_host_ecdsa_key.pub', 'ssh_host_rsa_key.pub'):
    present = subprocess.run(adb + ['shell', 'test', '-f', root + '/etc/ssh/' + key],
                             capture_output=True, timeout=10)
    if present.returncode == 0:
        (out / key).write_bytes(run('exec-out', 'cat', root + '/etc/ssh/' + key))
(out / 'mounts-after.txt').write_bytes(run('shell', 'cat', '/proc/mounts'))
report = {'ui': args.ui, 'package': profile['package'], 'package_sha256': profile['sha256'],
          'installed_through': 'OrangeFox ADB sideload', 'formats_userdata': True,
          'offline_backup_verified': True, 'adb_sideload_exit_status': sideload_status,
          'installer_completed': True, 'boot_readback_sha256': boot_hash,
          'boot_readback_matches': True, 'recovery_sha256': after_recovery,
          'recovery_unchanged': True, 'runtime_verified': False, 'user_checks': 'pending',
          'completed_at': datetime.now(timezone.utc).isoformat()}
(out / 'installation.json').write_text(json.dumps(report, indent=2) + '\n')
(out.parent / 'latest-attempt.txt').write_text(stamp + '\n')
print('UI_INSTALL_AND_BOOT_READBACK_VERIFIED; tablet remains in OrangeFox', flush=True)
print('Evidence: ' + str(out), flush=True)
