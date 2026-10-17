#!/usr/bin/env python3
"""Adapt the bounded native shutter test to a video with an acoustic marker."""
from pathlib import Path
workspace=Path(__file__).resolve().parents[1]
text=(workspace/'diagnostics/ui-qc-snapshot-photo-stress.sh').read_text()
text=text.replace("'capture-mode','picture'","'capture-mode','video'")
old='''for number in range(8):
    try:
        accepted=found[0].DoAction(found[1]);print('NATIVE_SHUTTER',number+1,'accepted',bool(accepted),flush=True)
        time.sleep(4)
    except dbus.DBusException as error:
        print('NATIVE_CAMERA_ACTION_FAILURE',error.get_dbus_name(),flush=True);break'''
new='''import array,math,subprocess,threading
from gi.repository import GLib
started=time.time()
def acoustic_marker():
    time.sleep(2);wave=array.array('h')
    for frame in range(48000*4):
        value=int(6000*math.sin(2*math.pi*887*frame/48000)) if (frame//24000)%2==0 else 0
        wave.extend((value,value))
    result=subprocess.run(['pacat','--playback','--raw','--format=s16le','--rate=48000','--channels=2','--volume=16000'],input=wave.tobytes(),capture_output=True,timeout=8)
    print('VIDEO_ACOUSTIC_MARKER_EXIT',result.returncode,flush=True)
assert found[0].DoAction(found[1]);print('NATIVE_VIDEO_STARTED',flush=True)
tone=threading.Thread(target=acoustic_marker,daemon=True);tone.start();time.sleep(8)
assert found[0].DoAction(found[1]);tone.join(timeout=3);time.sleep(4)
video_dir=Path(GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_VIDEOS))
files=[p for p in video_dir.rglob('*') if p.is_file() and p.stat().st_mtime>=started and p.suffix.lower() in ('.mp4','.webm')]
assert len(files)==1,('Expected one new test video',len(files))
import gi
gi.require_version('Gst','1.0');gi.require_version('GstPbutils','1.0')
from gi.repository import Gst,GstPbutils
Gst.init(None);uri=files[0].as_uri()
info=GstPbutils.Discoverer.new(10*Gst.SECOND).discover_uri(uri)
print('NATIVE_VIDEO_STREAMS','audio',len(info.get_audio_streams()),'video',len(info.get_video_streams()),'duration_seconds',round(info.get_duration()/Gst.SECOND,2),'bytes',files[0].stat().st_size,flush=True)
assert len(info.get_audio_streams())==1 and len(info.get_video_streams())==1
pipeline=Gst.parse_launch('uridecodebin uri="'+uri+'" name=decode decode. ! queue ! audioconvert ! audioresample ! audio/x-raw,format=S16LE,rate=48000,channels=1 ! appsink name=measure sync=false')
sink=pipeline.get_by_name('measure');pipeline.set_state(Gst.State.PLAYING)
levels=[];total=0;pending=array.array('h');deadline=time.monotonic()+15
try:
    while time.monotonic()<deadline:
        sample=sink.emit('try-pull-sample',Gst.SECOND)
        if sample:
            buffer=sample.get_buffer();ok,mapping=buffer.map(Gst.MapFlags.READ)
            if ok:
                pending.extend(array.array('h',bytes(mapping.data)));buffer.unmap(mapping)
                while len(pending)>=4800:
                    window=pending[:4800];del pending[:4800];mean=sum(window)/len(window)
                    levels.append(round(math.sqrt(sum((x-mean)**2 for x in window)/len(window)),1));total+=len(window)
        elif sink.get_property('eos'):break
finally:pipeline.set_state(Gst.State.NULL)
print('NATIVE_VIDEO_AUDIO_SAMPLES',total,'AC_RMS_100MS',levels,flush=True)
assert total>=48000*6 and max(levels[15:],default=0)>20
print('NATIVE_VIDEO_WITH_PHYSICAL_MICROPHONE_PASSED',flush=True)'''
assert old in text;text=text.replace(old,new)
text='\n'.join(line for line in text.splitlines() if not line.startswith((
    'new_files=[p for p in picture_dir',"print('NEW_NATIVE_STILL_PHOTOS'",'assert len(new_files)==8')))+'\n'
out=workspace/'artifacts/diagnostics/snapshot-video-audio-test.sh';out.write_text(text,newline='\n')
print('NATIVE_CAMERA_VIDEO_AUDIO_TEST_PREPARED')
