#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,pwd,signal,socket,subprocess,time
assert os.geteuid()==0
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,USER=user.pw_name,LOGNAME=user.pw_name,XDG_RUNTIME_DIR=f'/run/user/{uid}')
sockets=[p for p in Path(env['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket()]
assert len(sockets)==1;env['WAYLAND_DISPLAY']=sockets[0].name
identity=dict(user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid),env=env)
run=Path('/run/gta4l-camera-pipewire-test');binary=run/'gta4l-camera-pipewire'
assert hashlib.sha256(binary.read_bytes()).hexdigest()=='1371e5e86a307e40404484a8fdaeff66af3d1ad477a7f56ccef16da2d027b9fd'
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid==uid and ((p/'exe').resolve().name=='snapshot' or (p/'exe').resolve()==binary):
            os.kill(int(p.name),signal.SIGTERM)
    except (OSError,ProcessLookupError):pass
time.sleep(2)
for camera in ('rear','front'):
    log=open(run/(camera+'.log'),'wb');os.chmod(log.name,0o600)
    child=subprocess.Popen([str(binary),camera],stdout=log,stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL,start_new_session=True,**identity)
    log.close();print('REAL_CAMERA_SOURCE_STARTED',camera,child.pid,flush=True)
time.sleep(2)
code='''import gi,time,json,zlib
gi.require_version("Gst","1.0")
from gi.repository import Gst
Gst.init(None)
provider=Gst.DeviceProviderFactory.get_by_name("pipewiredeviceprovider")
assert provider.start();time.sleep(1)
for camera in ("rear","front"):
    device=next(d for d in provider.get_devices() if d.get_display_name()=="Galaxy Tab A7 "+camera.title()+" Camera")
    source=device.create_element(None)
    pipeline=Gst.parse_launch("capsfilter name=caps caps=video/x-raw,format=RGBx,width=640,height=480 ! appsink name=test sync=false max-buffers=2 drop=true")
    pipeline.add(source);assert source.link(pipeline.get_by_name("caps"))
    sink=pipeline.get_by_name("test");start=time.monotonic()
    pipeline.set_state(Gst.State.PLAYING)
    frames=0;checksums=set();first=None
    try:
        while time.monotonic()-start<32:
            sample=sink.emit("try-pull-sample",Gst.SECOND)
            if sample is None:continue
            buffer=sample.get_buffer();ok,info=buffer.map(Gst.MapFlags.READ);assert ok
            try:
                assert len(info.data)==640*480*4
                pixels=info.data[::40]
                nonblack=max(pixels)>25 and max(pixels)-min(pixels)>10
                if nonblack:
                    frames+=1;checksums.add(zlib.crc32(info.data))
                    if first is None:first=round(time.monotonic()-start,2)
            finally:buffer.unmap(info)
            if frames>=12:break
    finally:pipeline.set_state(Gst.State.NULL)
    print(json.dumps({"camera":camera,"first_nonblack_frame_seconds":first,"nonblack_frames":frames,"distinct_frames":len(checksums)}),flush=True)
    assert frames>=12 and len(checksums)>=2,"Missing real camera frames"
    time.sleep(2)
provider.stop()
'''
probe=subprocess.Popen(['python3','-c',code],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,**identity)
time.sleep(6)
frame=Path('/run/gta4l-camera/frames/frame.ppm')
if frame.exists():
    info=frame.stat()
    with frame.open('rb') as data:header=[data.readline(128).decode(errors='replace').strip() for _ in range(3)]
    print('BROKER_FRAME_STRUCTURE',info.st_uid,info.st_gid,oct(info.st_mode&0o777),info.st_size,header,flush=True)
else:print('BROKER_FRAME_NOT_PRESENT_AFTER_SIX_SECONDS',flush=True)
output,_=probe.communicate(timeout=79)
print('STANDARD_CLIENT_REAL_FRAME_CHECK',output[-7000:],flush=True)
for camera in ('rear','front'):print(camera,(run/(camera+'.log')).read_text()[-3000:],flush=True)
assert probe.returncode==0
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid==uid and (p/'exe').resolve().name=='snapshot':os.kill(int(p.name),signal.SIGTERM)
    except (OSError,ProcessLookupError):pass
time.sleep(3)
for attempt in range(15):
    try:
        with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as peer:
            peer.settimeout(1);peer.connect('/run/gta4l-camera/control.sock');peer.sendall(b'status\n')
            state=json.loads(peer.recv(4096));assert not state['running'];break
    except TimeoutError:time.sleep(.1)
else:raise RuntimeError('A camera consumer still owns capture')
print('BROKER_IDLE_AFTER_STANDARD_CLIENTS',not state['running'],flush=True)
assert not Path('/run/gta4l-camera/frames/frame.ppm').exists()
log=open(run/'snapshot.log','wb');os.chmod(log.name,0o600)
app=subprocess.Popen(['/usr/bin/gta4l-zink-run','/usr/sbin/snapshot'],stdout=log,stderr=subprocess.STDOUT,
    stdin=subprocess.DEVNULL,start_new_session=True,**identity)
log.close();time.sleep(3);assert app.poll() is None
print('GNOME_CAMERA_OPEN_FOR_VISUAL_CHECK',app.pid,flush=True)
PY
