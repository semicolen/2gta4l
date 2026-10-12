#!/usr/bin/env python3
"""Regression checks for mount aliases and aborts before formatting."""
from pathlib import Path
import os
import subprocess
import tempfile

workspace = Path(__file__).resolve().parents[1]
mounts = workspace / 'recovery/userdata-mounts.sh'
functions = workspace / 'recovery/partition-functions.sh'
for script in [mounts, functions, workspace / 'recovery/update-binary']:
    subprocess.run(['sh', '-n', str(script)], check=True)
with tempfile.TemporaryDirectory(prefix='gta4l-installer-test-') as name:
    temp = Path(name)
    info = temp / 'mountinfo'
    info.write_text('''1 1 0:2 / / rw - rootfs rootfs rw
40 1 259:48 / /data rw - f2fs /dev/block/mmcblk0p80 rw
41 1 259:48 /media/0 /sdcard rw - f2fs /dev/mmcblk0p80 rw
42 40 0:42 / /data/nested rw - tmpfs tmpfs rw
43 1 259:44 / /cache rw - ext4 /dev/block/mmcblk0p76 rw
''')
    result = subprocess.check_output(['sh', '-c', '. "$1"; gta4l_userdata_mounts 259:48 "$2"', 'test', str(mounts), str(info)], text=True)
    assert result.splitlines() == ['/data/nested', '/sdcard', '/data'], result
    print('PASS: device-number matching includes aliases and children, excludes cache')
    original_info = info.read_text()
    unmount_test = '''
. "$1"
info="$2"
umount() {
    echo "unmount $1"
    [ "$1" != "$BUSY_PATH" ] || return 1
    awk -v path="$1" '$5 != path' "$info" > "$info.next"
    mv "$info.next" "$info"
}
gta4l_unmount_mounts 259:48 "$info"
'''
    result = subprocess.run(['sh', '-c', unmount_test, 'test', str(mounts), str(info)], env=dict(os.environ, BUSY_PATH=''), capture_output=True, text=True)
    assert result.returncode == 0, result
    assert result.stdout.splitlines() == ['Unmounting userdata at /data/nested', 'unmount /data/nested', 'Unmounting userdata at /sdcard', 'unmount /sdcard', 'Unmounting userdata at /data', 'unmount /data'], result
    assert '259:48' not in info.read_text() and '/cache' in info.read_text()
    print('PASS: all userdata aliases unmounted, nested mounts first')
    info.write_text(original_info)
    result = subprocess.run(['sh', '-c', unmount_test, 'test', str(mounts), str(info)], env=dict(os.environ, BUSY_PATH='/sdcard'), capture_output=True, text=True)
    assert result.returncode == 1 and 'unmount /data\n' not in result.stdout, result
    assert '259:48' in info.read_text()
    print('PASS: busy mount aborts immediately without a forced/lazy unmount')
    log = temp / 'calls'
    mock = temp / 'bin'
    mock.mkdir()
    commands = {
        'blockdev': '#!/bin/sh\ncase "$1" in --getss) echo 512;; --getsize64) echo 23484414976;; esac\n',
        'dd': '#!/bin/sh\necho dd >> "$CALL_LOG"\n',
        'cmp': '#!/bin/sh\nexit 0\n',
        'kpartx': '#!/bin/sh\necho kpartx >> "$CALL_LOG"\nexit "$MAPPING_RESULT"\n',
    }
    for name, body in commands.items():
        target = mock / name
        target.write_text(body)
        target.chmod(0o755)
    env = dict(os.environ, PATH=str(mock) + ':' + os.environ['PATH'], CALL_LOG=str(log))
    install = '''
. "$1"
ui_print() { echo "$1"; }
gta4l_assert_userdata_idle() { return "$IDLE_RESULT"; }
gta4l_make_partition_table() { root_end=45867007; return "$TABLE_RESULT"; }
set_subpartitions() { PMOS_BOOT=/nonexistent/boot; ROOT_PARTITION=/nonexistent/root; }
INSTALL_PARTITION=userdata
INSTALL_DEVICE="$TARGET_DEVICE"
BOOT_PARTITION=/dev/block/mmcblk0p69
ISOREC=false
FDE=false
partition_install_device || { ui_print 'Partition setup failed; formatting and boot flashing stopped.'; exit 1; }
echo FORMATTING_REACHED
'''
    cases = [
        ('wrong target', dict(TARGET_DEVICE='/dev/block/mmcblk0', IDLE_RESULT='0', TABLE_RESULT='0', MAPPING_RESULT='0'), []),
        ('userdata still mounted', dict(TARGET_DEVICE='/dev/block/mmcblk0p80', IDLE_RESULT='1', TABLE_RESULT='0', MAPPING_RESULT='0'), []),
        ('table creation failed', dict(TARGET_DEVICE='/dev/block/mmcblk0p80', IDLE_RESULT='0', TABLE_RESULT='1', MAPPING_RESULT='0'), []),
        ('mapper resource busy', dict(TARGET_DEVICE='/dev/block/mmcblk0p80', IDLE_RESULT='0', TABLE_RESULT='0', MAPPING_RESULT='1'), ['dd', 'dd', 'dd', 'dd', 'kpartx']),
        ('mapper nodes absent', dict(TARGET_DEVICE='/dev/block/mmcblk0p80', IDLE_RESULT='0', TABLE_RESULT='0', MAPPING_RESULT='0'), ['dd', 'dd', 'dd', 'dd', 'kpartx']),
    ]
    for label, overrides, expected in cases:
        log.unlink(missing_ok=True)
        result = subprocess.run(['sh', '-c', install, 'test', str(functions)], env=dict(env, **overrides), capture_output=True, text=True)
        assert result.returncode == 1, (label, result)
        assert 'FORMATTING_REACHED' not in result.stdout, (label, result)
        assert (log.read_text().splitlines() if log.exists() else []) == expected, label
        print('PASS:', label, 'stops before formatting')
