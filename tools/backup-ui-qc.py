#!/usr/bin/env python3
"""Offline, read-only backup of the working tablet before clean UI tests."""
from pathlib import Path
import argparse,hashlib,json,queue,shutil,subprocess,threading,time
parser=argparse.ArgumentParser();parser.add_argument('--serial',required=True)
parser.add_argument('--fast',action='store_true')
parser.add_argument('--resume',action='store_true')
args=parser.parse_args()
assert not args.resume or args.fast,'Resume requires the verified native helper'
workspace=Path(__file__).resolve().parents[1]
adb=['adb','-s',args.serial]
def query(*command):return subprocess.check_output(adb+['shell',*command],text=True,timeout=20).strip()
assert query('id','-u')=='0'
assert query('getprop','ro.product.device')=='gta4l'
assert query('getprop','ro.bootloader').startswith('T505')
assert query('getprop','ro.product.model') in ('SM-T505','SM_T505')
out=workspace/'artifacts/backups/ui-qc-working-system'
out.mkdir(parents=True,exist_ok=True)
assert not (out/'manifest.json').exists(),'Completed backup already exists; review it before replacing'
node='/dev/block/by-name/userdata'
resolved=query('readlink','-f',node)
assert resolved=='/dev/block/mmcblk0p80',resolved
assert resolved not in query('cat','/proc/mounts'),'Userdata must be unmounted'
expected=int(query('blockdev','--getsize64',node))
assert expected==23484415488,expected
assert shutil.disk_usage(out).free>expected+2*1024**3,'Insufficient local backup space'
report={'device':'SM-T505','serial':args.serial,'backup_type':'offline raw partitions',
        'userdata_mounted':False,'read_only_device_operation':True,'partitions':{}}
for name in ('boot','recovery','dtbo','vbmeta','vbmeta_samsung','efs','sec_efs','modemst1','modemst2','persist'):
    block='/dev/block/by-name/'+name
    size=int(query('blockdev','--getsize64',block))
    assert 0<size<=128*1024**2
    dest=out/(name+'.img')
    if not (args.resume and dest.is_file()):
        with dest.open('wb') as stream:subprocess.run(adb+['exec-out','cat',block],stdout=stream,check=True,timeout=120)
    assert dest.stat().st_size==size
    with dest.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
    if name=='boot':
        stable=(workspace/'artifacts/boot-current.img').read_bytes()
        with dest.open('rb') as stream:assert stream.read(len(stable))==stable,'Unexpected working boot image'
    report['partitions'][name]={'bytes':size,'sha256':digest}
    print('Saved '+name+' ('+str(size)+' bytes)',flush=True)
(out/'manifest-in-progress.json').write_text(json.dumps(report,indent=2)+'\n')
# Tee the single device read into a device-side hash, keeping stdout binary.
fifo='/tmp/gta4l-qc-backup.fifo';digest_path='/tmp/gta4l-qc-backup.sha256'
script=f'''set -e
test ! -e {fifo}
mkfifo {fifo}
sha256sum {fifo} > {digest_path} &
hasher=$!
cat {node} | tee {fifo}
wait "$hasher"
rm {fifo}
'''
dest=out/'userdata.img';partial=out/'userdata.img.partial'
local_script=out/'userdata-stream.sh'
local_script.write_text(script,newline='\n')
remote_script='/tmp/gta4l-qc-backup-stream.sh'
subprocess.run(adb+['push',str(local_script),remote_script],check=True,capture_output=True,timeout=20)
hasher=hashlib.sha256();saved=0
if args.resume:
    assert partial.is_file() and 0<partial.stat().st_size<expected
    with partial.open('rb') as source:
        while data:=source.read(1024*1024):hasher.update(data);saved+=len(data)
initial=saved;start=time.monotonic();last=start
command=adb+['exec-out','sh',remote_script]
if args.fast:
    command=adb+['exec-out','/tmp/gta4l-qc-tools/qc-backup-stream',node,digest_path,str(saved)]
    print('Native backup helper; resuming after '+str(saved)+' bytes',flush=True)
with partial.open('ab' if args.resume else 'wb') as target,(out/'userdata-transfer.stderr').open('wb') as errors:
    process=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=errors)
    incoming=queue.Queue(maxsize=8)
    def read_stream():
        try:
            while data:=process.stdout.read(1024*1024):incoming.put(data)
            incoming.put(None)
        except Exception as error:incoming.put(error)
    threading.Thread(target=read_stream,daemon=True).start()
    last_data=start
    try:
        while True:
            try:data=incoming.get(timeout=5)
            except queue.Empty:
                now=time.monotonic()
                # A resumed helper first hashes the retained prefix on the tablet.
                assert now-last_data<(600 if saved==initial else 90),'Backup stream stalled; partial retained for resume'
                if now-last>=20:
                    print('Waiting for backup stream; '+str(saved)+' bytes retained',flush=True)
                    last=now
                continue
            if data is None:break
            if isinstance(data,Exception):raise data
            target.write(data);hasher.update(data);saved+=len(data)
            assert saved<=expected,'Backup stream exceeded partition size'
            now=time.monotonic();last_data=now
            if now-last>=20:
                print('Userdata backup '+str(round(100*saved/expected,1))+'%; '+str(round((saved-initial)/(now-start)/1024**2,1))+' MiB/s',flush=True)
                last=now
        assert process.wait(timeout=20)==0
    finally:
        if process.poll() is None:process.terminate();process.wait(timeout=10)
assert saved==expected and partial.stat().st_size==expected,(saved,expected)
device_digest=query('cat',digest_path).split()[0]
assert device_digest==hasher.hexdigest(),'Device and host backup digests differ'
partial.replace(dest)
report['partitions']['userdata']={'bytes':expected,'sha256':device_digest,'device_hash_matches':True}
report['verified_complete']=True
(out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('WORKING_SYSTEM_OFFLINE_BACKUP_VERIFIED',flush=True)
