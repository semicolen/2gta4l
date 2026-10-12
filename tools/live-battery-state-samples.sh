#!/bin/sh
set -eu
python3 -u - <<'PY'
from pathlib import Path
import dbus,json,time
bus=dbus.SystemBus()
manager=bus.get_object('org.freedesktop.UPower','/org/freedesktop/UPower')
interface=dbus.Interface(manager,'org.freedesktop.UPower')
paths=list(interface.EnumerateDevices())+[interface.GetDisplayDevice()]
fields=('NativePath','Type','State','Online','PowerSupply','Percentage','Energy','EnergyFull','EnergyRate','Voltage','Temperature','TimeToEmpty','TimeToFull','UpdateTime')
for index in range(4):
    sample={'index':index,'time':int(time.time()),'kernel':{},'upower':[]}
    props=dbus.Interface(manager,'org.freedesktop.DBus.Properties').GetAll('org.freedesktop.UPower')
    sample['manager']={key:props[key] for key in ('OnBattery','LidIsClosed','LidIsPresent') if key in props}
    for name in ('battery','bms','cw2017-bat','usb','pc_port','otg'):
        root=Path('/sys/class/power_supply')/name
        sample['kernel'][name]={key:(root/key).read_text().strip() for key in ('status','capacity','current_now','current_avg','voltage_now','temp','online','present','current_max') if (root/key).exists()}
    for path in paths:
        values=dbus.Interface(bus.get_object('org.freedesktop.UPower',path),'org.freedesktop.DBus.Properties').GetAll('org.freedesktop.UPower.Device')
        sample['upower'].append({'path':str(path),**{key:values[key] for key in fields if key in values}})
    print('BATTERY_SAMPLE='+json.dumps(sample,sort_keys=True,default=str))
    if index<3:time.sleep(8)
print('UPOWER_VERSION='+str(props.get('DaemonVersion','unknown')))
print('BATTERY_STATE_SAMPLES_END')
PY
