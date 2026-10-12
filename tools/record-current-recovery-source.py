"""Mark a completed local source ZIP; packaging requires this exact hash."""
from pathlib import Path
import hashlib,json,zipfile
base=Path('/home/pmos/sm-t505-port');workspace=Path(__file__).resolve().parents[1]
source=base/'work/chroot_buildroot_aarch64/var/lib/postmarketos-android-recovery-installer/pmos-samsung-gta4l.zip'
with zipfile.ZipFile(source) as archive:
    assert len(archive.namelist())==len(set(archive.namelist()))
    assert 'rootfs.tar.gz' in archive.namelist()
with source.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
report=dict(source=str(source),sha256=digest,bytes=source.stat().st_size)
marker=workspace/'artifacts/current-recovery-source-ready.json'
temporary=marker.with_suffix('.tmp');temporary.write_text(json.dumps(report,indent=2)+'\n')
temporary.replace(marker)
print('CURRENT_RECOVERY_SOURCE_READY: '+str(report['bytes'])+' bytes')
