#!/usr/bin/env python3
"""Exercise rejection paths without touching any tablet or block device."""
from pathlib import Path
import os
import subprocess
import tempfile

script = Path(__file__).resolve().parents[1] / 'recovery/update-binary'
subprocess.run(['sh', '-n', str(script)], check=True)
with tempfile.TemporaryDirectory(prefix='gta4l-preflight-') as temp:
    mock = Path(temp)
    commands = {
        'getprop': '#!/bin/sh\ncase "$1" in ro.product.device) echo "$TEST_DEVICE";; ro.product.model) echo "$TEST_MODEL";; ro.bootloader) echo "$TEST_BOOTLOADER";; esac\n',
        'id': '#!/bin/sh\necho 0\n',
        'readlink': '#!/bin/sh\ncase "$2" in */boot) echo "$TEST_BOOT_NODE";; */userdata) echo /dev/block/mmcblk0p80;; esac\n',
        'blockdev': '#!/bin/sh\ncase "$2" in *p69) echo "$TEST_BOOT_BYTES";; *p80) echo "$TEST_DATA_BYTES";; esac\n',
        'unzip': '#!/bin/sh\necho ERROR_EXTRACTION_REACHED\nexit 99\n',
    }
    for name, content in commands.items():
        path = mock / name
        path.write_text(content)
        path.chmod(0o755)
    base = dict(os.environ, PATH=str(mock) + ':' + os.environ['PATH'],
                TEST_DEVICE='gta4l', TEST_MODEL='SM-T505', TEST_BOOTLOADER='T505XXS8CXG1',
                TEST_BOOT_NODE='/dev/block/mmcblk0p69', TEST_BOOT_BYTES='100663296',
                TEST_DATA_BYTES='23484414976')
    cases = {
        'wrong codename': {'TEST_DEVICE': 'other'},
        'Wi-Fi-only T500': {'TEST_MODEL': 'SM-T500', 'TEST_BOOTLOADER': 'T500XXU1'},
        'wrong boot mapping': {'TEST_BOOT_NODE': '/dev/block/mmcblk0p12'},
        'wrong boot size': {'TEST_BOOT_BYTES': '33554432'},
        'undersized userdata': {'TEST_DATA_BYTES': '1048576'},
    }
    for name, overrides in cases.items():
        result = subprocess.run(['sh', str(script), '3', '1', '/does-not-exist.zip'], env=dict(base, **overrides), text=True, capture_output=True)
        assert result.returncode == 1, (name, result)
        assert 'preflight failed' in result.stdout, (name, result)
        assert 'ERROR_EXTRACTION_REACHED' not in result.stdout, name
        print('PASS:', name)
    result = subprocess.run(['sh', str(script), '3', '1', '/sdcard/pmos.zip'], env=base, text=True, capture_output=True)
    assert result.returncode == 1 and 'preflight failed' in result.stdout, result
    assert 'ERROR_EXTRACTION_REACHED' not in result.stdout, result
    print('PASS: installer ZIP on internal Android storage')
