#!/bin/sh
set -eu
python3 - <<'PY'
import ctypes
import fcntl
import json
import os
from pathlib import Path
import struct

# ABI from the pinned kernel's cam_defs.h and cam_sensor.h. QUERY_CAP only
# copies driver metadata; this helper sends no probe, power or stream command.
assert ctypes.sizeof(ctypes.c_void_p) == 8
assert struct.calcsize('<IIIIQ') == 24
cam_control_ioctl = (3 << 30) | (24 << 16) | (ord('V') << 8) | 192
schemas = {
    'cam-sensor-driver': ('slot_info', 'secure_camera', 'pos_pitch',
        'pos_roll', 'pos_yaw', 'actuator_slot_id', 'eeprom_slot_id',
        'ois_slot_id', 'flash_slot_id', 'csiphy_slot_id'),
    'cam-csiphy-driver': ('slot_info', 'version', 'clk_lane', 'reserved'),
}
result = []
for entry in sorted(Path('/sys/class/video4linux').glob('v4l-subdev*')):
    name = (entry/'name').read_text().strip()
    if name not in schemas:
        continue
    fields = schemas[name]
    payload = ctypes.create_string_buffer(4 * len(fields))
    control = bytearray(struct.pack('<IIIIQ', 0x101, len(payload), 1, 0,
                                    ctypes.addressof(payload)))
    row = dict(device='/dev/' + entry.name, driver=name)
    fd = None
    try:
        fd = os.open(row['device'], os.O_RDWR | os.O_NONBLOCK)
        fcntl.ioctl(fd, cam_control_ioctl, control, True)
        values = struct.unpack('<' + 'I' * len(fields), payload.raw)
        row['capabilities'] = dict(zip(fields, values))
    except OSError as exc:
        row['errno'] = exc.errno
        row['error'] = str(exc)
    finally:
        if fd is not None:
            os.close(fd)
    result.append(row)
print(json.dumps(result, indent=2))
print('CAMERA_NATIVE_QUERY_END')
PY
