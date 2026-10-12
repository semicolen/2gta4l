#!/bin/sh
set -u
echo '=== Selected panel device tree ==='
python3 - <<'PY'
from pathlib import Path
import struct
base = Path('/sys/firmware/devicetree/base')
for panel in base.rglob('qcom,mdss_dsi_hx83102e_inx_fhd_video'):
    print('PANEL:', panel)
    for prop in panel.iterdir():
        if prop.is_file() and any(x in prop.name for x in ['gpio', 'reset', 'on-command', 'off-command', 'dstb', 'bl-', 'lp11', 'supply', 'flag']):
            value = prop.read_bytes()
            print(prop.name, len(value), value.hex())
print('=== Touch gesture controls ===')
for root in ['/sys/android_touch', '/proc/android_touch', '/sys/devices/platform/soc']:
    path = Path(root)
    if path.exists():
        if root.endswith('/soc'):
            continue
        print(root, [p.name for p in path.iterdir()])
PY
echo '=== GPIO state ==='
cat /sys/kernel/debug/gpio 2>/dev/null || true
echo '=== Display debug files ==='
find /sys/kernel/debug -maxdepth 3 -type f | grep -E '/dri/|dsi|regulator' | head -n 70
echo '=== Panel regulator state ==='
cat /sys/kernel/debug/regulator/regulator_summary 2>/dev/null | grep -E 'l[0-9]|ibb|ab |dsi|vddio|panel' || true
echo PANEL_RESUME_STATE_END
