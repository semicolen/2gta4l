"""Inspect local build inputs without exposing account or Wi-Fi credentials."""
from pathlib import Path
import json
base=Path('/home/ark/sm-t505-port')
root=base/'work/chroot_rootfs_samsung-gta4l'
selected={'linux-samsung-gta4l','device-samsung-gta4l','camera-gta4l','gps-gta4l',
          'rotation-gta4l','sensors-gta4l','iio-sensor-proxy','modemmanager','geoclue',
          'onboard','xfce-polkit','xfce4-screensaver','postmarketos-ui-xfce4',
          'lightdm','networkmanager','bubblewrap-gta4l','xorg-modesetting-gta4l'}
installed={}
for section in (root/'lib/apk/db/installed').read_text().split('\n\n'):
    values=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
    if values.get('P') in selected:installed[values['P']]=values['V']
print('LOCAL_ROOTFS_SELECTED_PACKAGES='+json.dumps(installed,sort_keys=True))
print('LOCAL_ROOTFS_DEFAULT_SERVICES='+json.dumps(sorted(p.name for p in (root/'etc/runlevels/default').iterdir())))
print('LOCAL_ROOTFS_WORLD='+json.dumps((root/'etc/apk/world').read_text().splitlines()))
print('LOCAL_ROOTFS_BOOT_BYTES='+str((root/'boot/boot.img').stat().st_size))
for path in ('usr/bin/gta4l-camera','usr/bin/gta4l-rotate',
             'etc/xdg/autostart/onboard-autostart.desktop','etc/xdg/autostart/xfce-polkit.desktop'):
    print(path+' present='+str((root/path).exists()))
