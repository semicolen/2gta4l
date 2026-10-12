#!/bin/sh
set -eu
python3 -u - <<'PY'
from pathlib import Path
import json
root=Path('/sys/class/power_supply/battery')
keys=('health','temp','step_charging_enabled','sw_jeita_enabled','charge_done','input_current_limited','constant_charge_current','constant_charge_current_max','voltage_max','charge_term_current','store_mode','batt_slate_mode','charging_enabled','battery_charging_enabled')
values={key:(root/key).read_text().strip() for key in keys if (root/key).exists()}
print('BATTERY_PROTECTION_PROPERTIES='+json.dumps(values,sort_keys=True))
tree=Path('/sys/firmware/devicetree/base')
# Only charger/gauge/profile values; skip chosen bootargs and device identities.
for node in tree.rglob('compatible'):
    compatible=node.read_bytes().replace(b'\0',b',').decode(errors='replace')
    if not any(item in compatible for item in ('qpnp-smb5','qpnp-qg','cellwise,cw2017','qcom,battery-data')):continue
    data={}
    for prop in sorted(node.parent.iterdir()):
        if not prop.is_file() or prop.name in ('phandle','linux,phandle','name'):continue
        if prop.name not in ('compatible','reg','status') and not prop.name.startswith(('qcom,','cw,','cellwise,')):continue
        raw=prop.read_bytes()
        if len(raw)>1200:continue
        data[prop.name]={'bytes':len(raw),'hex':raw.hex()}
    print('BATTERY_DT_NODE='+json.dumps({'path':str(node.parent.relative_to(tree)),'properties':data},sort_keys=True))
print('BATTERY_PROTECTION_STATE_END')
PY
