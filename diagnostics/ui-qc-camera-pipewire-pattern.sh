#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,pwd,signal,subprocess,time
assert os.geteuid()==0
shells=[]
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell':shells.append(p)
    except (OSError,ProcessLookupError):pass
assert len(shells)==1
shell=shells[0];uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,USER=user.pw_name,LOGNAME=user.pw_name,XDG_RUNTIME_DIR=f'/run/user/{uid}')
sockets=[p for p in Path(env['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket()]
assert len(sockets)==1;env['WAYLAND_DISPLAY']=sockets[0].name
run=Path('/run/gta4l-camera-pipewire-test');run.mkdir(mode=0o755,exist_ok=True)
assert run.stat().st_uid==0 and not run.is_symlink()
binary=run/'gta4l-camera-pipewire'
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and (p/'exe').resolve()==binary:
            os.kill(int(p.name),signal.SIGTERM)
    except (OSError,ProcessLookupError):pass
time.sleep(1)
uploaded=Path('/tmp/gta4l-upload/gta4l-camera-pipewire')
assert uploaded.read_bytes()[:4]==b'\x7fELF'
binary.write_bytes(uploaded.read_bytes());binary.chmod(0o755)
print('CAMERA_ADAPTER_SHA256',hashlib.sha256(binary.read_bytes()).hexdigest(),flush=True)
print('LOGGED_IN_UID',uid,flush=True)
identity=dict(user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid),env=env)
for camera in ('rear','front'):
    log=open(run/(camera+'.log'),'wb');os.chmod(log.name,0o600)
    child=subprocess.Popen([str(binary),camera,'--test-pattern'],stdout=log,stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL,start_new_session=True,**identity)
    log.close();print('SOURCE_STARTED',camera,child.pid,flush=True)
time.sleep(3)
probe_code='''import gi,time,json
gi.require_version("Gst","1.0")
from gi.repository import Gst
Gst.init(None)
provider=Gst.DeviceProviderFactory.get_by_name("pipewiredeviceprovider")
assert provider and provider.start()
time.sleep(2)
nodes=[]
for device in provider.get_devices():
    props=device.get_properties()
    if props and str(props.get_value("node.name") or "").startswith("gta4l.camera."):
        nodes.append({"name":device.get_display_name(),"class":device.get_device_class(),"caps":device.get_caps().to_string()})
print(json.dumps(nodes),flush=True)
provider.stop()
assert len(nodes)==2
'''
probe=subprocess.run(['python3','-c',probe_code],capture_output=True,text=True,timeout=10,**identity)
print('GSTREAMER_PIPEWIRE_CAMERAS',probe.stdout,flush=True)
assert probe.returncode==0,probe.stderr
stream_code='''import gi,json,time
gi.require_version("Gst","1.0")
from gi.repository import Gst
Gst.init(None)
provider=Gst.DeviceProviderFactory.get_by_name("pipewiredeviceprovider")
assert provider.start();time.sleep(1)
for camera in ("rear","front"):
    device=next(d for d in provider.get_devices() if d.get_display_name()=="Galaxy Tab A7 "+camera.title()+" Camera")
    source=device.create_element(None);source.set_property("num-buffers",12)
    print("STREAM_TARGET",camera,source.get_property("target-object"),flush=True)
    pipeline=Gst.parse_launch("capsfilter name=caps caps=video/x-raw,format=RGBx,width=640,height=480 ! appsink name=test sync=false")
    pipeline.add(source);assert source.link(pipeline.get_by_name("caps"))
    sink=pipeline.get_by_name("test")
    pipeline.set_state(Gst.State.PLAYING)
    frames=0;correct=0
    try:
        for i in range(12):
            sample=sink.emit("try-pull-sample",3*Gst.SECOND)
            assert sample is not None,"No frame from "+camera
            buffer=sample.get_buffer();ok,info=buffer.map(Gst.MapFlags.READ)
            assert ok
            try:
                assert len(info.data)==640*480*4
                pixels=[tuple(info.data[(100*640+x)*4:(100*640+x)*4+3]) for x in (50,320,600)]
                correct+=pixels==[(220,0,0),(0,220,0),(0,0,220)]
            finally:buffer.unmap(info)
            frames+=1
    finally:pipeline.set_state(Gst.State.NULL)
    print(json.dumps({"camera":camera,"frames":frames,"correct_test_pattern_frames":correct}),flush=True)
    assert correct>=8
provider.stop()
'''
stream=subprocess.run(['python3','-c',stream_code],capture_output=True,text=True,timeout=20,**identity)
print('GSTREAMER_PATTERN_FRAME_CHECK',stream.stdout,stream.stderr[-2000:],flush=True)
assert stream.returncode==0
for camera in ('rear','front'):print(camera,(run/(camera+'.log')).read_text()[-2000:],flush=True)
print('PIPEWIRE_PATTERN_SOURCES_READY',flush=True)
PY
