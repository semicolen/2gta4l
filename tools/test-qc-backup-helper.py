from pathlib import Path
import hashlib,subprocess,time
workspace=Path(__file__).resolve().parents[1]
adb=['adb','-s','R9WNC1QG0LJ']
bundle=workspace/'artifacts/qc-backup-tools'
subprocess.run(adb+['shell','mkdir','-p','/tmp/gta4l-qc-tools/lib'],check=True)
for name in ('qc-backup-stream','ld-musl-aarch64.so.1','lib/libcrypto.so.3'):
    subprocess.run(adb+['push',str(bundle/name),'/tmp/gta4l-qc-tools/'+name],check=True,capture_output=True)
subprocess.run(adb+['shell','chmod','755','/tmp/gta4l-qc-tools/qc-backup-stream','/tmp/gta4l-qc-tools/ld-musl-aarch64.so.1'],check=True)
target=workspace/'artifacts/qc-backup-tools/boot-test.img'
start=time.monotonic()
with target.open('wb') as stream:
    result=subprocess.run(adb+['exec-out','/tmp/gta4l-qc-tools/qc-backup-stream',
        '/dev/block/by-name/boot','/tmp/gta4l-qc-test.sha256','0'],stdout=stream,stderr=subprocess.PIPE)
assert result.returncode==0,result.stderr.decode(errors='replace')
assert target.stat().st_size==100663296
with target.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
with (workspace/'artifacts/backups/ui-qc-working-system/boot.img').open('rb') as stream:
    assert digest==hashlib.file_digest(stream,'sha256').hexdigest()
device_digest=subprocess.check_output(adb+['shell','cat','/tmp/gta4l-qc-test.sha256'],text=True).strip()
assert device_digest==digest
print('NATIVE_ARM64_BACKUP_HELPER_VERIFIED '+str(round(96/(time.monotonic()-start),1))+' MiB/s')
