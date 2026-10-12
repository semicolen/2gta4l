#!/bin/sh
set -eu
umask 077
mkdir -p /var/log/gta4l/gps-private
chmod 700 /var/log/gta4l/gps-private
qmicli -d qrtr://0 --loc-set-nmea-types='gga|gsa|gsv|rmc|vtg'
mmcli -m 0 --location-get -J > /var/log/gta4l/gps-private/location.json
python3 - <<'PY'
import json
from pathlib import Path
v=json.loads(Path('/var/log/gta4l/gps-private/location.json').read_text())['modem']['location']['gps']
try:
    lat=float(v.get('latitude')); lon=float(v.get('longitude'))
    present=-90 <= lat <= 90 and -180 <= lon <= 180
except (TypeError,ValueError): present=False
print('raw_coordinates_present='+str(present))
print('nmea_sentence_count='+str(len(v.get('nmea',[]))))
nmea_position=False
for text in v.get('nmea',[]):
    for line in text.splitlines():
        p=line.split('*')[0].split(',')
        if not p or not p[0].startswith('$'): continue
        typ=p[0][-3:]
        if typ=='GGA' and len(p)>9:
            print(p[0]+' quality='+p[6]+' satellites='+p[7]+' hdop='+p[8])
            try:
                a=float(p[2]); b=float(p[4])
                nmea_position |= (int(p[6])>0 and 0<=a<=9000 and 0<=b<=18000
                    and a%100<60 and b%100<60 and p[3] in ('N','S') and p[5] in ('E','W'))
            except (ValueError,IndexError): pass
        elif typ=='RMC' and len(p)>2: print(p[0]+' status='+p[2])
        elif typ=='GSV' and len(p)>3:
            snr=[p[n] for n in range(7,len(p),4) if p[n]]
            print(p[0]+' visible='+p[3]+' snr='+','.join(snr))
        elif typ=='GSA' and len(p)>2: print(p[0]+' fix_type='+p[2])
print('nmea_coordinates_present='+str(nmea_position))
PY
printf 'GPS_NMEA_SUMMARY_END\n'
