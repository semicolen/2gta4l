#!/bin/sh
# Exercise the native app's accessible shutter action; keep all photos on-device.
set -eu
python3 - <<'PY'
from pathlib import Path
import os,pwd,signal,subprocess,time
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,USER=user.pw_name,XDG_RUNTIME_DIR=f'/run/user/{uid}',RUST_LOG='snapshot=debug,aperture=debug',GST_DEBUG='2',GST_DEBUG_NO_COLOR='1')
env['WAYLAND_DISPLAY']=next(p.name for p in Path(env['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket())
identity=dict(env=env,user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid))
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid==uid and (p/'exe').resolve().name=='snapshot':os.kill(int(p.name),signal.SIGTERM)
    except (OSError,ProcessLookupError):pass
time.sleep(2)
old_mode=subprocess.check_output(['gsettings','get','org.gnome.Snapshot','capture-mode'],text=True,timeout=5,**identity).strip()
old_sound=subprocess.check_output(['gsettings','get','org.gnome.Snapshot','play-shutter-sound'],text=True,timeout=5,**identity).strip()
camera_name=''
old_camera=subprocess.check_output(['gsettings','get','org.gnome.Snapshot','last-camera-id'],text=True,timeout=5,**identity).strip()
if camera_name:
    assert camera_name in ('Galaxy Tab A7 Rear Camera','Galaxy Tab A7 Front Camera')
    subprocess.run(['gsettings','set','org.gnome.Snapshot','last-camera-id',camera_name],check=True,timeout=5,**identity)
    print('CAMERA_UNDER_TEST',camera_name,flush=True)
subprocess.run(['gsettings','set','org.gnome.Snapshot','capture-mode','picture'],check=True,timeout=5,**identity)
subprocess.run(['gsettings','set','org.gnome.Snapshot','play-shutter-sound','true'],check=True,timeout=5,**identity)
run=Path('/run/gta4l-snapshot-stress');run.mkdir(mode=0o700,exist_ok=True)
assert not run.is_symlink() and run.stat().st_uid==0
log=open(run/'snapshot.log','wb');os.chmod(log.name,0o600)
app_command=['/usr/sbin/snapshot']
debugger_mode=False
if debugger_mode:
    app_command=['gdb','--batch','-ex','set pagination off','-ex','set confirm off','-ex','set debuginfod enabled off','-ex','set print frame-arguments none','-ex','run','-ex','thread apply all bt 8','--args',*app_command]
app=subprocess.Popen(app_command,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,**identity)
log.close();time.sleep(7)
code='''import dbus,time
from pathlib import Path
from gi.repository import GLib
picture_dir=Path(GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_PICTURES))
previous={p for p in picture_dir.rglob('*') if p.is_file()}
bus=dbus.SessionBus()
address=dbus.Interface(bus.get_object('org.a11y.Bus','/org/a11y/bus'),'org.a11y.Bus').GetAddress()
a11y=dbus.bus.BusConnection(str(address));daemon=dbus.Interface(a11y.get_object('org.freedesktop.DBus','/org/freedesktop/DBus'),'org.freedesktop.DBus')
root=a11y.get_object('org.a11y.atspi.Registry','/org/a11y/atspi/accessible/root')
found=None
for child in dbus.Interface(root,'org.a11y.atspi.Accessible').GetChildren():
    try:
        pid=int(daemon.GetConnectionUnixProcessID(child[0]))
        if (Path('/proc')/str(pid)/'exe').resolve().name!='snapshot':continue
        app=a11y.get_object(child[0],child[1]);acc=dbus.Interface(app,'org.a11y.atspi.Accessible')
        for window in acc.GetChildren():
            action=dbus.Interface(a11y.get_object(window[0],window[1]),'org.a11y.atspi.Action')
            actions=list(action.GetActions())
            for index,item in enumerate(actions):
                if str(item[0])=='win.take-picture':found=(action,index)
    except (dbus.DBusException,OSError):continue
assert found,'Native shutter action unavailable'
for number in range(8):
    try:
        accepted=found[0].DoAction(found[1]);print('NATIVE_SHUTTER',number+1,'accepted',bool(accepted),flush=True)
        time.sleep(4)
    except dbus.DBusException as error:
        print('NATIVE_CAMERA_ACTION_FAILURE',error.get_dbus_name(),flush=True);break
new_files=[p for p in picture_dir.rglob('*') if p.is_file() and p not in previous and p.suffix.lower() in ('.jpg','.jpeg','.png')]
print('NEW_NATIVE_STILL_PHOTOS',len(new_files),'sizes',[p.stat().st_size for p in new_files],flush=True)
assert len(new_files)==8 and all(p.stat().st_size>1000 for p in new_files),'Not all native still photos were saved'
'''
probe=subprocess.run(['python3','-c',code],capture_output=True,text=True,timeout=45,**identity)
print(probe.stdout,probe.stderr,flush=True)
print('SNAPSHOT_PROCESS_STATUS',app.poll(),flush=True)
subprocess.run(['gsettings','set','org.gnome.Snapshot','capture-mode',old_mode],check=True,timeout=5,**identity)
subprocess.run(['gsettings','set','org.gnome.Snapshot','play-shutter-sound',old_sound],check=True,timeout=5,**identity)
subprocess.run(['gsettings','set','org.gnome.Snapshot','last-camera-id',old_camera],check=True,timeout=5,**identity)
print('SNAPSHOT_PHOTO_DIAGNOSTICS', (run/'snapshot.log').read_text(errors='replace')[-18000:],flush=True)
print('NATIVE_CAMERA_STRESS_COMPLETE',flush=True)
assert probe.returncode==0 and app.poll() is None,'Native Camera stress did not pass'
PY
