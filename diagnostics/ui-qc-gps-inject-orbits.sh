#!/bin/sh
# Fetch receiver-advertised orbit assistance. No location is sent or printed.
set -eu
umask 077
python3 - <<'PY'
from pathlib import Path
import dbus,hashlib,json,os,tempfile,time,urllib.request,urllib.parse
assert os.geteuid()==0
bus=dbus.SystemBus()
objects=dbus.Interface(bus.get_object('org.freedesktop.ModemManager1','/org/freedesktop/ModemManager1'),
    'org.freedesktop.DBus.ObjectManager').GetManagedObjects()
path=next(p for p,v in objects.items() if 'org.freedesktop.ModemManager1.Modem.Location' in v)
obj=bus.get_object('org.freedesktop.ModemManager1',path)
props=dbus.Interface(obj,'org.freedesktop.DBus.Properties').GetAll('org.freedesktop.ModemManager1.Modem.Location')
assert int(props['SupportedAssistanceData'])&1
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):raise ValueError('Assistance redirects are not allowed')
opener=urllib.request.build_opener(NoRedirect)
data=None;source=None
for value in props['AssistanceDataServers']:
    url=str(value);parsed=urllib.parse.urlsplit(url)
    assert parsed.scheme=='https' and parsed.hostname in ('path1.xtracloud.net','path2.xtracloud.net','path3.xtracloud.net')
    assert parsed.path=='/xtra3grcej.bin' and not parsed.query and not parsed.fragment and not parsed.username
    try:
        request=urllib.request.Request(url,headers={'User-Agent':'postmarketOS-gta4l-gps/1.0'})
        with opener.open(request,timeout=15) as response:
            assert response.status==200
            data=response.read(2*1024*1024+1)
        assert 1024<=len(data)<=2*1024*1024
        assert not data.lstrip().startswith((b'<',b'{'))
        source=parsed.hostname;break
    except (OSError,ValueError) as error:
        print('ORBIT_DOWNLOAD_RETRY',parsed.hostname,type(error).__name__,flush=True)
assert data is not None and source
print('ORBIT_DOWNLOAD',source,'bytes',len(data),'sha256',hashlib.sha256(data).hexdigest(),flush=True)
start=time.monotonic()
dbus.Interface(obj,'org.freedesktop.ModemManager1.Modem.Location').InjectAssistanceData(dbus.ByteArray(data),timeout=90)
print('MODEM_ACCEPTED_ORBIT_ASSISTANCE_SECONDS',round(time.monotonic()-start,2),flush=True)
cache=Path('/var/cache/gta4l-gps-assistance');cache.mkdir(mode=0o700,parents=True,exist_ok=True)
assert not cache.is_symlink() and cache.stat().st_uid==0
cache.chmod(0o700)
fd,name=tempfile.mkstemp(prefix='.orbits-',dir=cache)
try:
    with os.fdopen(fd,'wb') as stream:stream.write(data);stream.flush();os.fsync(stream.fileno())
    os.replace(name,cache/'xtra3grcej.bin')
finally:
    if os.path.exists(name):os.unlink(name)
(cache/'state.json').write_text(json.dumps({'downloaded_at':int(time.time()),'injected_at':int(time.time()),
    'source':source,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})+'\n')
(cache/'state.json').chmod(0o600)
print('GPS_ORBIT_ASSISTANCE_INJECTION_COMPLETE',flush=True)
PY
timeout 15 qmicli -d qrtr://0 --loc-get-predicted-orbits-data-validity
