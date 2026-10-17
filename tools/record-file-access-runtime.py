#!/usr/bin/env python3
"""Accept only the saved hardware checks for the exact installed #11 candidate."""
from pathlib import Path
import argparse,hashlib,json,re

workspace=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('evidence',type=Path)
args=parser.parse_args()
folder=args.evidence.resolve()
assert folder.is_relative_to(workspace/'evidence/ui-qc/gnome')
report_path=workspace/'artifacts/file-access-kernel-fix-verification.json'
report=json.loads(report_path.read_text())
installation=json.loads((folder/'installation.json').read_text())
assert installation['kernel_build_version']==report['kernel_build_version']=='#11-postmarketOS'
assert installation['boot_readback_matches'] and installation['recovery_unchanged']
assert installation['boot_sha256']==report['boot_sha256']
assert not installation['formats_userdata']
boot=workspace/'artifacts'/report['boot_filename']
assert hashlib.sha256(boot.read_bytes()).hexdigest()==report['boot_sha256']
checks={name:(folder/name).read_text() for name in ('faccessat2-gio-permissions.txt','arm32-compat.txt',
                                                   'pidfd-himax-regression.txt','compositor.txt')}
assert 'FACCESSAT2_AND_GIO_PERMISSION_REGRESSION_PASS' in checks['faccessat2-gio-permissions.txt']
assert 'PASS tablet-user Gio present, absent and dangling-link checks' in checks['faccessat2-gio-permissions.txt']
assert checks['arm32-compat.txt'].strip()=='ARM32_FACCESSAT2_COMPAT_PASS'
assert 'KERNEL_PIDFD_RUNTIME_API_AND_HIMAX_BITS_PASS' in checks['pidfd-himax-regression.txt']
assert re.search(r'^Capabilities:\s+keyboard touch\s*$',checks['pidfd-himax-regression.txt'],re.M)
assert '#11-postmarketOS' in checks['compositor.txt']
assert 'GNOME_USER_COMPOSITOR_PRIVATE_ZINK_AND_ADRENO_DEVICE_VERIFIED' in checks['compositor.txt']
report.update(runtime_verified=True,normal_boots_verified=1,
              faccessat2_permissions_and_tablet_user_gio_passed=True,
              arm32_faccessat2_compat_dispatch_passed=True,
              pidfd_status_ownership_error_checks_passed=True,
              libinput_himax_keyboard_touch_without_pointer=True,
              gnome_adreno_compositor_verified=True,
              runtime_evidence=folder.relative_to(workspace).as_posix(),
              runtime_evidence_sha256={name:hashlib.sha256((folder/name).read_bytes()).hexdigest() for name in checks},
              user_visual_regression_pending=True)
report_path.write_text(json.dumps(report,indent=2)+'\n')
print('KERNEL11_HARDWARE_API_INPUT_AND_COMPOSITOR_RECEIPT_VERIFIED')
