#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import dbus,hashlib,json,os,pwd,subprocess,time
print('NORMAL_BOOT_KERNEL',subprocess.check_output(['uname','-v'],text=True).strip(),flush=True)
with open('/dev/mmcblk0p69','rb') as stream:
    assert hashlib.sha256(stream.read(28938256)).hexdigest()=='30514abd03d82b8ade4fe1cb5f0698f30fcd54d56301111635bb51ad2f93147b'
for name in ('gta4l-gps-assistance','gta4l-camera','modemmanager'):
    p=subprocess.run(['rc-service',name,'status'],capture_output=True,text=True,timeout=8)
    print('PERSISTENT_SERVICE',name,p.returncode,p.stdout.strip(),p.stderr.strip(),flush=True);assert p.returncode==0
manager=dbus.Interface(dbus.SystemBus().get_object('org.freedesktop.ModemManager1','/org/freedesktop/ModemManager1'),'org.freedesktop.DBus.ObjectManager')
for v in manager.GetManagedObjects().values():
    location=v.get('org.freedesktop.ModemManager1.Modem.Location')
    if location:print('POSTBOOT_GPS_SOURCE_MASK',int(location['Enabled']),flush=True)
shell=None
for attempt in range(20):
    for p in Path('/proc').iterdir():
        try:
            if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell':shell=p;break
        except (OSError,ProcessLookupError):pass
    if shell:break
    time.sleep(1)
if shell is None:print('NORMAL_BOOT_AWAITING_USER_LOGIN',flush=True);raise SystemExit(2)
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,USER=user.pw_name,XDG_RUNTIME_DIR=f'/run/user/{uid}',LC_ALL='C',LANG='C')
identity=dict(env=env,user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid))
def pulse(*args):return subprocess.check_output(['pactl',*args],text=True,timeout=10,**identity)
sources=json.loads(pulse('-f','json','list','sources'))
microphones=[s for s in sources if s['name'].startswith('alsa_input.') and s.get('properties',{}).get('alsa.card')=='0']
assert len(microphones)==1
print('POSTBOOT_PHYSICAL_MICROPHONE',[(s['name'],s['sample_specification'],s['mute'],s['state']) for s in microphones],flush=True)
print('POSTBOOT_DEFAULT_RECORDING_SOURCE',pulse('get-default-source').strip(),flush=True)
print('POSTBOOT_SPEAKER',pulse('list','short','sinks').strip(),flush=True)
print('POSTBOOT_CAPTURE_PCM',Path('/proc/asound/card0/pcm0c/sub0/status').read_text().strip(),flush=True)
helpers=[]
for attempt in range(20):
    helpers=[]
    for p in Path('/proc').iterdir():
        try:
            if p.name.isdigit() and p.stat().st_uid==uid:
                exe=(p/'exe').resolve()
                args=(p/'cmdline').read_bytes().split(b'\0')
                if exe.name=='gta4l-camera-pipewire':helpers.append(('source',int(p.name)))
                elif b'/usr/libexec/gta4l-camera-pipewire-session' in args:helpers.append(('supervisor',int(p.name)))
        except (OSError,ProcessLookupError):pass
    if sum(n=='source' for n,p in helpers)==2 and sum(n=='supervisor' for n,p in helpers)==1:break
    time.sleep(1)
print('AUTOMATIC_CAMERA_HELPERS',helpers,flush=True)
assert sum(n=='source' for n,p in helpers)==2 and sum(n=='supervisor' for n,p in helpers)==1
print('POSTBOOT_GNOME_RENDER_DRIVER',env.get('GALLIUM_DRIVER'),env.get('GTA4L_ZINK_KGSL'),flush=True)
print('AUDIO_CAMERA_GPS_NORMAL_BOOT_PASSED',flush=True)
PY
