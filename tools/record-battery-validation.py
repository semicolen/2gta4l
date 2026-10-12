"""Record the bounded battery reporting audit without claiming a full charge test."""
from pathlib import Path
import hashlib,json,statistics
root=Path(__file__).resolve().parents[1]
evidence=root/'evidence/diagnostic-boot-20261009'
names=('device-r21-battery-inventory.raw','device-r21-battery-state-samples.raw',
       'device-r21-battery-protection-state.raw','device-r21-battery-desktop-policy.raw',
       'device-r21-battery-screen-load-controlled.raw')
texts={name:(evidence/name).read_text() for name in names}
def entries(name,prefix):
    return [json.loads(line[len(prefix):]) for line in texts[name].splitlines() if line.startswith(prefix)]
supplies={item['name']:item['properties'] for item in entries(names[0],'POWER_SUPPLY=')}
samples=entries(names[1],'BATTERY_SAMPLE=')
assert len(samples)==4 and 'BATTERY_STATE_SAMPLES_END' in texts[names[1]]
assert supplies['battery']['capacity']==supplies['cw2017-bat']['capacity']
assert all(sample['manager']['OnBattery']==0 and sample['kernel']['pc_port']['online']=='1' for sample in samples)
assert all(sample['kernel']['pc_port']['current_max']=='500000' for sample in samples)
estimates=[]
for sample in samples:
    battery=next(item for item in sample['upower'] if item['NativePath']=='battery')
    assert battery['Percentage']==float(sample['kernel']['battery']['capacity'])
    if battery['State']==1 and battery['EnergyRate']>0:
        calculated=3600*(battery['EnergyFull']-battery['Energy'])/battery['EnergyRate']
        assert abs(calculated-battery['TimeToFull'])<1.1
        estimates.append({'seconds':battery['TimeToFull'],'hours':round(battery['TimeToFull']/3600,2),
                          'net_power_w':battery['EnergyRate']})
assert len(estimates)>=3 and estimates[2]['seconds']>estimates[0]['seconds']
protection=entries(names[2],'BATTERY_PROTECTION_PROPERTIES=')[0]
assert protection['sw_jeita_enabled']=='1' and protection['step_charging_enabled']=='1'
assert protection['store_mode']=='0' and protection['batt_slate_mode']=='0'
policy=entries(names[3],'UPOWER_POLICY=')[0]
assert policy['UsePercentageForPolicy']=='true'
config=(root/'port/linux-samsung-gta4l/config-samsung-gta4l.aarch64').read_text()
assert '# CONFIG_DISABLE_TEMP_PROTECT is not set' in config
load=entries(names[4],'SCREEN_LOAD_SAMPLE=')
assert 'SCREEN_RESTORED_ON' in texts[names[4]] and 'SCREEN_LOAD_TEST_END' in texts[names[4]]
for item in load:
    blank=item['values']['panel']['bl_power']=='4'
    assert blank==(item['phase']=='screen-off'), 'Screen state did not match test phase'
medians={phase:statistics.median(int(item['values']['battery']['current_now']) for item in load if item['phase']==phase)
         for phase in sorted({item['phase'] for item in load})}
report={
    'device':'SM-T505','date':'2026-10-12','kernel_release':9,'device_release':21,
    'battery_readings':supplies['battery'],
    'usb_input_limit_ua':500000,'desktop_line_power_detected':True,
    'upower_version':'1.91.0','charging_estimates_reproduced':estimates,
    'estimate_formula_verified':True,'percentage_matches_primary_cw2017_gauge':True,
    'kernel_charger_state_and_upower_net_discharge_distinction_confirmed':True,
    'protection_status':protection,'temperature_protection_bypass_disabled':True,
    'desktop_policy':policy,'screen_load_median_battery_current_ua':medians,
    'battery_current_sign':'positive means net charge, negative means net discharge in the primary battery supply',
    'screen_restored_on':True,'charging_limits_changed':False,'packages_or_boot_changed':False,
    'full_design_equality_is_not_measured_battery_health':True,
    'unverified':['wall-charger negotiation and charge rate','full charge and termination','long discharge/runtime',
                  'thermal cutoff operation under fault/temperature extremes','system suspend',
                  'low-battery shutdown execution','physical battery wear'],
    'evidence_sha256':{name:hashlib.sha256((evidence/name).read_bytes()).hexdigest() for name in names},
    'source_references':{
        'upower':'https://gitlab.freedesktop.org/upower/upower/-/tree/v1.91.0',
        'upower_archive_sha512':'32801d3ee4c5086221a9f12062b0f2e6765b239f68a562c24ef7808999bb34e299e6acd31acf5c414cf41613709c97b20ad64d252e1d8ddf23183576b156cf93',
        'upower_current_state':'src/linux/up-device-supply-battery.c:519',
        'upower_time_formula':'src/up-device-battery.c:355',
        'kernel_gauge_selection':'drivers/power/supply/qcom/smb5-lib.c:994',
        'kernel_current_sign':'drivers/power/supply/qcom/smb5-lib.c:2625',
        'kernel_nominal_capacity_fallback':'drivers/power/supply/qcom/qpnp-qg.c:2228',
        'kernel_commit':'381a5549ee66fa751f632ee0840f5631274209ee'}}
(root/'artifacts/battery-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('BATTERY_REPORTING_AUDIT_PASSED')
print('SCREEN_MEDIAN_CURRENT_UA='+json.dumps(medians,sort_keys=True))
print('FULL_CHARGE_AND_WALL_CHARGER_NOT_TESTED')
