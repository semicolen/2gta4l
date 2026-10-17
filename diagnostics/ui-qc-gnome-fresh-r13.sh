#!/bin/sh
set -eu
grep -q '#11-postmarketOS' /proc/version
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,pwd,grp,tempfile
from gi.repository import Gio
assert os.geteuid()==0
records={}
for block in Path('/lib/apk/db/installed').read_text().split('\n\n'):
    fields=dict(line.split(':',1) for line in block.splitlines() if ':' in line)
    if 'P' in fields:records[fields['P']]=fields['V']
expected={'linux-samsung-gta4l':'4.19.300-r10','device-samsung-gta4l':'1-r23',
          'camera-gta4l':'1.0-r5','mesa-zink-kgsl-gta4l':'26.0.8-r3','iio-sensor-proxy':'3.9-r4'}
assert all(records.get(name)==version for name,version in expected.items())
compat=json.loads(Path('/etc/gta4l-ui-compat.json').read_text())
assert compat['ui'] in ('gnome','gnome-mobile') and compat['revision']==6 and compat['gnome_gtk_opengl']
wrapper=Path('/usr/bin/gta4l-gnome-session')
assert hashlib.sha256(wrapper.read_bytes()).hexdigest()=='1310ca486f2072a2e1a974cd2e42902a146f1bfbfe1d24c1868e0298c5f404cf'
assert wrapper.stat().st_uid==0 and wrapper.stat().st_mode&0o777==0o755
assert 'Exec=/usr/bin/gta4l-zink-run /usr/bin/gta4l-gnome-session' in Path('/usr/share/wayland-sessions/gnome.desktop').read_text()
user=pwd.getpwnam('quickUser')
assert user.pw_uid==10001
groups=os.getgrouplist(user.pw_name,user.pw_gid)
assert {grp.getgrgid(g).gr_name for g in groups}=={'quickUser','wheel','video','audio','netdev','plugdev'}
print('FRESH_GNOME_PROFILE',compat['ui'],'PORT_VERSIONS_AND_SESSION_WRAPPER_PASS',flush=True)
pid=os.fork()
if pid==0:
    try:
        os.setgroups(groups);os.setgid(user.pw_gid);os.setuid(user.pw_uid)
        with tempfile.TemporaryDirectory(prefix='gta4l-fresh-rootfs-check-') as directory:
            present=Path(directory)/'present';present.write_text('temporary fresh-image check\n')
            assert Gio.File.new_for_path(str(present)).query_exists(None)
            assert not Gio.File.new_for_path(str(present.with_name('missing'))).query_exists(None)
        assert all(os.access(node,os.R_OK|os.W_OK) for node in ('/dev/kgsl-3d0','/dev/ion'))
        print('FRESH_QUICKUSER_GIO_AND_GPU_ACCESS_PASS',flush=True)
        os._exit(0)
    except BaseException:
        import traceback;traceback.print_exc();os._exit(1)
assert os.waitpid(pid,0)[1]==0
print('BOOT_ID',Path('/proc/sys/kernel/random/boot_id').read_text().strip(),flush=True)
PY
