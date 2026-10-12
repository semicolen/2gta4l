#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
CHROOT="$ROOT/work/chroot_buildroot_aarch64"
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/modemmanager-gps-build-initial.log"
python3 "$WORKSPACE/tools/configure-port.py"
cp -a "$WORKSPACE/port/modemmanager" "$ROOT/sources/pmaports/device/downstream/"
python3 - <<'PY'
from pathlib import Path
p=Path('/home/pmos/sm-t505-port/work/chroot_buildroot_aarch64/home/pmos/build/APKBUILD')
s=p.read_text()
assert 'pkgname=modemmanager\n' in s
s=s.replace('checkdepends="glib-dev py3-gobject3 py3-dbus"','checkdepends="dbus glib-dev py3-gobject3 py3-dbus"')
p.write_text(s)
PY
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- apk add dbus
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/sh -c 'cd /home/pmos/build; busybox su pmos -c "HOME=/home/pmos PMB_CROSS=crossdirect PATH=/native/usr/lib/crossdirect/aarch64:/usr/lib/ccache/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin abuild -d -D postmarketOS check rootpkg index"'
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/modemmanager-gps-build.log"
for pkg in modemmanager modemmanager-openrc modemmanager-udev libmm-glib; do
    cp "$ROOT/work/packages/edge/aarch64/$pkg-1.25.95_git20261005-r1.apk" "$WORKSPACE/artifacts/apks/"
done
echo MODEMMANAGER_GPS_TESTS_AND_PACKAGING_COMPLETE
