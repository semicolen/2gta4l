#!/bin/sh
set -eu
python3 -u - <<'PY'
from pathlib import Path
import json,os,re,subprocess
config=Path('/etc/UPower/UPower.conf')
allowed=('UsePercentageForPolicy','PercentageLow','PercentageCritical','PercentageAction','CriticalPowerAction','AllowRiskyCriticalPowerAction')
entries={}
if config.exists():
    for line in config.read_text().splitlines():
        if line.startswith('#') or '=' not in line:continue
        key,value=line.split('=',1)
        if key.strip() in allowed:entries[key.strip()]=value.strip()
print('UPOWER_POLICY='+json.dumps(entries,sort_keys=True))
print('POWER_DAEMONS='+json.dumps(sorted({(node/'comm').read_text().strip() for node in Path('/proc').iterdir() if node.name.isdigit() and (node/'comm').exists() and (node/'comm').read_text().strip() in ('upowerd','xfce4-power-man','elogind','systemd-logind')})))
PY
