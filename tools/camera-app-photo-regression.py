#!/usr/bin/env python3
"""Exercise the installed GTK app's real preview, shutter and PNG-save path."""
import argparse,hashlib,json,os,struct,time
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--camera',choices=('rear','front'),required=True)
parser.add_argument('--app-sha256',required=True)
options=parser.parse_args()
app=Path('/usr/bin/gta4l-camera')
source=app.read_bytes()
assert hashlib.sha256(source).hexdigest()==options.app_sha256
# r2's CLI starts Gtk.main at module scope. Load only its unchanged class and
# imports, then use the same GTK shutter signal and save implementation.
prefix,separator,_=source.decode().partition('\narguments=argparse.ArgumentParser()')
assert separator
namespace={'__name__':'gta4l_camera_regression'}
exec(compile(prefix,str(app),'exec'),namespace)
Gtk,GLib=namespace['Gtk'],namespace['GLib']
os.umask(0o077)
window=namespace['Camera']();window.show_all()
folder=Path.home()/'Pictures/Camera'
before=set(folder.glob('*.png'))
started=time.monotonic();phase='preview';result=1;saved=None

def tick():
    global phase,result,saved
    if time.monotonic()-started>80:
        print('CAMERA_NATIVE_PHOTO_TIMEOUT phase='+phase+' status='+json.dumps(window.status),flush=True)
        window.destroy();return False
    if phase=='preview' and window.last_frame is not None and window.preview_camera==options.camera:
        print('CAMERA_NATIVE_PREVIEW_READY camera='+options.camera,flush=True)
        window.save.emit('clicked');phase='photo'
    elif phase=='photo' and not window.taking_photo:
        added=set(folder.glob('*.png'))-before
        assert len(added)==1,('Native app did not save one photo',window.label.get_text())
        saved=added.pop()
        with saved.open('rb') as image:header=image.read(24)
        assert header[:8]==b'\x89PNG\r\n\x1a\n'
        size=struct.unpack('>II',header[16:24])
        expected={'rear':(3264,2448),'front':(2592,1944)}[options.camera]
        assert sorted(size)==sorted(expected),size
        assert saved.stat().st_mode & 0o777==0o600
        print('CAMERA_NATIVE_PHOTO_SAVED camera=%s width=%d height=%d bytes=%d' %
              (options.camera,*size,saved.stat().st_size),flush=True)
        phase='restart'
    elif phase=='restart' and window.status.get('mode')=='preview' and window.status.get('frames',0)>=2:
        print('CAMERA_NATIVE_PREVIEW_RESTARTED camera='+options.camera,flush=True)
        result=0;window.destroy();return False
    return True

def checked_tick():
    try:return tick()
    except Exception as error:
        print('CAMERA_NATIVE_PHOTO_REGRESSION_ERROR '+repr(error),flush=True)
        window.destroy();return False

GLib.idle_add(window.select,options.camera)
GLib.timeout_add(250,checked_tick)
Gtk.main()
print('CAMERA_NATIVE_PHOTO_REGRESSION_EXIT='+str(result),flush=True)
raise SystemExit(result)
