#!/bin/sh
set -eu
nmcli -t -f DEVICE,TYPE,STATE device status
python3 - <<'PY'
import json,subprocess,http.client,ssl
try:interfaces=json.loads(subprocess.check_output(['ip','-j','-4','addr','show','dev','wlan0'],text=True))
except subprocess.CalledProcessError:
    print('WIFI_NOT_CONFIGURED; no network test attempted',flush=True)
    raise SystemExit(0)
addresses=[a['local'] for interface in interfaces for a in interface.get('addr_info',[]) if a.get('scope')=='global']
if not addresses:
    print('WIFI_NOT_CONFIGURED; no network test attempted',flush=True)
    raise SystemExit(0)
subprocess.run(['ping','-I','wlan0','-c','2','-W','2','1.1.1.1'],check=False,timeout=8)
connection=http.client.HTTPSConnection('postmarketos.org',timeout=12,source_address=(addresses[0],0),context=ssl.create_default_context())
try:
    connection.request('HEAD','/')
    response=connection.getresponse()
    print('WIFI_CERTIFICATE_VALIDATED_HTTPS_STATUS',response.status,flush=True)
    assert 200<=response.status<400
finally:connection.close()
print('GNOME_WIFI_DNS_AND_CERTIFICATE_VALIDATED_HTTPS_PASS',flush=True)
PY
