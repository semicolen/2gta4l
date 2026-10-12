#!/bin/sh
set -eu
python3 -u - <<'PY'
from pathlib import Path
import json,os,subprocess,time,statistics
env={**os.environ,'DISPLAY':':0','XAUTHORITY':'/home/tablet/.Xauthority'}
samples={}
def xset(*args):
    subprocess.run(['xset',*args],env=env,check=True,timeout=5,stdout=subprocess.DEVNULL)
def sample(phase):
    values={}
    for name in ('battery','bms','pc_port','usb'):
        root=Path('/sys/class/power_supply')/name
        values[name]={key:(root/key).read_text().strip() for key in ('current_now','current_avg','capacity','temp','voltage_now','online','status','current_max') if (root/key).exists()}
    panel=Path('/sys/class/backlight/panel0-backlight')
    values['panel']={key:(panel/key).read_text().strip() for key in ('brightness','actual_brightness','bl_power') if (panel/key).exists()}
    print('SCREEN_LOAD_SAMPLE='+json.dumps({'phase':phase,'time':int(time.time()),'values':values},sort_keys=True))
    samples.setdefault(phase,[]).append(int(values['battery']['current_now']))
try:
    xset('dpms','force','on')
    time.sleep(3)
    for _ in range(4):sample('screen-on-before');time.sleep(2)
    xset('dpms','force','off')
    time.sleep(3)
    for _ in range(6):sample('screen-off');time.sleep(2)
finally:
    xset('dpms','force','on')
    print('SCREEN_RESTORED_ON')
time.sleep(3)
for _ in range(4):sample('screen-on-after');time.sleep(2)
print('SCREEN_LOAD_MEDIAN_CURRENT_UA='+json.dumps({key:statistics.median(value) for key,value in samples.items()},sort_keys=True))
print('SCREEN_LOAD_TEST_END')
PY
