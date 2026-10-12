#!/bin/sh
set -eu
python3 -u - <<'PY'
from pathlib import Path
import json,re,subprocess,xml.etree.ElementTree as ET
fields=('type','status','present','health','technology','capacity','capacity_level',
        'voltage_now','voltage_avg','voltage_max','voltage_min_design','voltage_max_design',
        'current_now','current_avg','current_max','input_current_limit','input_suspend',
        'charge_now','charge_full','charge_full_design','charge_counter','charge_type',
        'charge_control_limit','charge_control_limit_max','constant_charge_current_max',
        'constant_charge_voltage_max','temp','temp_min','temp_max','cycle_count',
        'energy_now','energy_full','energy_full_design','online','usb_type','model_name',
        'manufacturer','authentic','scope','charging_enabled','battery_charging_enabled',
        'batt_fcc','batt_soh','batt_cycle','batt_temp','batt_charging_source')
def read(path):
    try:return path.read_text().strip()
    except OSError:return None
print('boot_id='+read(Path('/proc/sys/kernel/random/boot_id')))
for supply in sorted(Path('/sys/class/power_supply').iterdir()):
    data={field:read(supply/field) for field in fields if (supply/field).exists()}
    try:data['driver']=str((supply/'device/driver').resolve(strict=True))
    except FileNotFoundError:pass
    print('POWER_SUPPLY='+json.dumps({'name':supply.name,'properties':data},sort_keys=True))
for zone in sorted(Path('/sys/class/thermal').glob('thermal_zone*')):
    entry={'name':zone.name,'type':read(zone/'type'),'temp':read(zone/'temp'),
           'mode':read(zone/'mode'),'policy':read(zone/'policy'),'trips':[]}
    for trip in sorted(zone.glob('trip_point_*_type')):
        stem=trip.name.removesuffix('_type')
        entry['trips'].append({'type':read(trip),'temp':read(zone/(stem+'_temp'))})
    print('THERMAL_ZONE='+json.dumps(entry,sort_keys=True))
try:
    import dbus
    bus=dbus.SystemBus()
    manager=bus.get_object('org.freedesktop.UPower','/org/freedesktop/UPower')
    interface=dbus.Interface(manager,'org.freedesktop.UPower')
    for path in interface.EnumerateDevices():
        device=bus.get_object('org.freedesktop.UPower',path)
        values=dbus.Interface(device,'org.freedesktop.DBus.Properties').GetAll('org.freedesktop.UPower.Device')
        selected={key:values[key] for key in ('Type','State','IsPresent','IsRechargeable','PowerSupply',
            'Percentage','Capacity','Energy','EnergyEmpty','EnergyFull','EnergyFullDesign','EnergyRate',
            'Voltage','Temperature','TimeToEmpty','TimeToFull','WarningLevel','NativePath') if key in values}
        print('UPOWER_DEVICE='+json.dumps(selected,sort_keys=True,default=str))
except Exception as error:print('UPOWER_QUERY_ERROR='+str(error))
file=Path('/home/tablet/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml')
if file.exists():
    print('XFCE_POWER_CONFIG='+json.dumps([{key:node.attrib[key] for key in ('name','type','value') if key in node.attrib}
        for node in ET.parse(file).iter('property')],sort_keys=True))
print('SUPPORTED_SLEEP_STATES='+str(read(Path('/sys/power/state'))))
for path in ('/sys/class/backlight/panel0-backlight/brightness',
             '/sys/class/backlight/panel0-backlight/max_brightness'):
    print(path+'='+str(read(Path(path))))
kernel=subprocess.run(['dmesg'],capture_output=True,text=True,timeout=5).stdout.splitlines()
pattern=r'\bbatt|\bqg\b|smb5|jeita|fuel.?gauge|charge.*(fail|err)|thermal.*(fail|err)'
for line in [line for line in kernel if 'Kernel command line:' not in line and re.search(pattern,line,re.I)][-100:]:
    print('BATTERY_KERNEL='+line)
print('BATTERY_INVENTORY_END')
PY
