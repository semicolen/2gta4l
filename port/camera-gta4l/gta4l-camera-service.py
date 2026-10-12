#!/usr/bin/env python3
"""On-demand stock HAL capture, restricted to the local video group.

One connected client owns the camera. Disconnect or five seconds without a
request stops it. The protocol accepts only fixed camera names and status/stop;
no client-controlled executable, path, environment or shell code is accepted.
"""
from collections import deque
import grp, json, os
from pathlib import Path
import pwd, re, signal, socket, struct, subprocess, threading

RUN=Path('/run/gta4l-camera')
STATE=Path('/var/lib/gta4l-camera')
GROUP=grp.getgrnam('video').gr_gid
CLIENT_COMMANDS={'rear','front','stop','status','photo','photo-done'}
process=None
collector=None
camera=None
mode=None
photo_id=0
frames=0
events=deque(maxlen=200)
runner=os.environ.get('GTA4L_CAMERA_RUNNER','/usr/libexec/gta4l-camera-run')

def prepare_directory(path,mode,gid):
    if path.is_symlink(): raise RuntimeError('Refusing symlink: '+str(path))
    path.mkdir(parents=True,exist_ok=True)
    os.chown(path,0,gid); os.chmod(path,mode)

def collect_output(child):
    global frames
    for data in child.stdout:
        line=data.decode(errors='replace').rstrip()[:2048]
        events.append(line)
        match=re.search(r'CAMERA_CAPTURE .*frame=(\d+) result=0 ',line)
        if match: frames=int(match[1])

def stop_camera():
    global process,camera,collector,mode
    if process is not None:
        if process.poll() is None:
            # The private process group includes unshare/chroot and HAL threads.
            os.killpg(process.pid,signal.SIGTERM)
            try: process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid,signal.SIGKILL); process.wait(timeout=5)
        if collector is not None: collector.join(timeout=2)
        (STATE/'last-session.log').write_text('\n'.join(events)+'\n')
        os.chmod(STATE/'last-session.log',0o600)
        process=None; collector=None
    camera=None; mode=None
    for name in ('frame.ppm','photo.ppm'):
        for path in (RUN/'frames').glob(name+'*'):
            path.unlink(missing_ok=True)

def photo_valid():
    path=RUN/'frames/photo.ppm'
    try:
        with path.open('rb') as source:
            if source.readline()!=b'P6\n': return False
            size=tuple(map(int,source.readline().split()))
            if size!=({'rear':(3264,2448),'front':(2592,1944)}.get(camera)): return False
            return source.readline()==b'255\n' and path.stat().st_size==source.tell()+size[0]*size[1]*3
    except (OSError,ValueError): return False

def status():
    finished=process is not None and process.poll() is not None
    return {'camera':camera,'running':process is not None and process.poll() is None,
            'frames':frames,'width':640,'height':480,
            'mode':mode,'photo_id':photo_id,
            'photo_ready':mode=='photo' and finished and process.returncode==0 and photo_valid(),
            'exit_status':None if process is None else process.poll()}

def start_camera(name,taking_photo=False):
    global process,camera,frames,collector,mode,photo_id
    stop_camera()
    frames=0; events.clear(); camera=name
    mode='photo' if taking_photo else 'preview'
    if taking_photo: photo_id+=1
    environment=dict(os.environ)
    environment['LD_LIBRARY_PATH']=''
    command=name+'-photo' if taking_photo else name
    process=subprocess.Popen([runner,command],env=environment,stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,start_new_session=True,umask=0o027)
    collector=threading.Thread(target=collect_output,args=(process,),daemon=True)
    collector.start()

def allowed(peer):
    uid=struct.unpack('3i',peer.getsockopt(socket.SOL_SOCKET,socket.SO_PEERCRED,12))[1]
    if uid==0: return True
    try: account=pwd.getpwuid(uid)
    except KeyError: return False
    return GROUP in os.getgrouplist(account.pw_name,account.pw_gid)

def serve_client(peer):
    if not allowed(peer): return
    peer.settimeout(5)
    pending=b''
    try:
        while True:
            chunk=peer.recv(256)
            if not chunk: break
            pending+=chunk
            if len(pending)>256: break
            while b'\n' in pending:
                line,pending=pending.split(b'\n',1)
                command=line.decode('ascii',errors='strict')
                if command not in CLIENT_COMMANDS:
                    response={'error':'Unsupported camera command'}
                else:
                    if command in ('rear','front'): start_camera(command)
                    elif command=='stop': stop_camera()
                    elif command=='photo':
                        if mode!='preview' or camera not in ('rear','front'):
                            peer.sendall(b'{"error":"Start a camera before taking a photo"}\n')
                            continue
                        start_camera(camera,taking_photo=True)
                    elif command=='photo-done':
                        if mode!='photo' or process is None or process.poll() is None:
                            peer.sendall(b'{"error":"No completed photo capture"}\n')
                            continue
                        if collector is not None: collector.join(timeout=2)
                        # Preserve bounded diagnostics before the preview starts.
                        (STATE/'last-photo.log').write_text('\n'.join(events)+'\n')
                        os.chmod(STATE/'last-photo.log',0o600)
                        start_camera(camera)
                    response=status()
                peer.sendall(json.dumps(response).encode()+b'\n')
    except (OSError,UnicodeError,ValueError): pass
    finally: stop_camera()

def shutdown(_number,_frame):
    stop_camera()
    raise SystemExit(0)

def main():
    if os.getuid()!=0: raise SystemExit('Camera service must run as root')
    prepare_directory(RUN,0o750,GROUP)
    prepare_directory(RUN/'frames',0o2750,GROUP)
    prepare_directory(STATE,0o700,0)
    address=RUN/'control.sock'
    address.unlink(missing_ok=True)
    signal.signal(signal.SIGTERM,shutdown); signal.signal(signal.SIGINT,shutdown)
    with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as listener:
        listener.bind(str(address)); os.chown(address,0,GROUP); os.chmod(address,0o660)
        listener.listen(2)
        try:
            while True:
                peer,_=listener.accept()
                with peer: serve_client(peer)
        finally:
            stop_camera(); address.unlink(missing_ok=True)

if __name__=='__main__': main()
