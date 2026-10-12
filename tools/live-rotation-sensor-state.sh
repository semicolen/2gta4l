#!/bin/sh
set -eu
echo '=== Kernel and session ==='
uname -a
ps -eo pid,uid,args | grep -E 'xfce4-session|Xorg|sensor|ssc' | grep -v grep || true
echo '=== Sensor device nodes and interfaces ==='
python3 - <<'PY'
from pathlib import Path
for pattern in ['iio*', '*sensor*', '*dsps*', '*ssc*', '*slpi*']:
    for node in Path('/dev').glob(pattern):
        print(node)
for directory in ['/sys/bus/iio/devices', '/sys/class/sensors', '/sys/class/input']:
    path = Path(directory)
    print(directory, 'exists='+str(path.exists()))
    if path.exists():
        for node in sorted(path.iterdir()):
            print(node)
            for name in ['name', 'device/name']:
                value = node/name
                if value.is_file():
                    print(name, value.read_text().strip())
PY
echo '=== QRTR services ==='
command -v qrtr-lookup && qrtr-lookup || true
echo '=== Sensor/display packages ==='
apk info -v | grep -Ei 'sensor|protobuf|qrtr|xrandr|xfce4|input' | sort
echo '=== Xorg display and touch transform ==='
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
su tablet -s /bin/sh -c 'DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority xrandr --query; DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority xinput list' || true
echo '=== Sensor firmware/driver messages ==='
dmesg | grep -Ei 'sensor|ssc|slpi|dsps|accel|bmi|bma|lsm6' | tail -n 70 || true
echo ROTATION_SENSOR_STATE_END
