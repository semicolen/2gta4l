from pathlib import Path
import hashlib,subprocess
workspace=Path(__file__).resolve().parents[1]
adb=['adb','-s','R9WNC1QG0LJ']
source=(workspace/'artifacts/qc-backup-tools/lib/libcrypto.so.3').read_bytes()
offset=1048577
result=subprocess.run(adb+['exec-out','/tmp/gta4l-qc-tools/qc-backup-stream',
    '/tmp/gta4l-qc-tools/lib/libcrypto.so.3','/tmp/gta4l-qc-resume-test.sha256',str(offset)],capture_output=True,check=True,timeout=30)
assert result.stdout==source[offset:]
digest=subprocess.check_output(adb+['shell','cat','/tmp/gta4l-qc-resume-test.sha256'],text=True).strip()
assert digest==hashlib.sha256(source).hexdigest()
print('ARM64_RESUME_OFFSET_AND_FULL_INPUT_HASH_VERIFIED')
