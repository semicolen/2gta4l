#!/bin/sh
set -eu
expected=faf5a4a554ffa5b01f2adc92b5fee47719e46b5db4542b3b42be225d451cebef
boot_hash() { head -c 28934160 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = "$expected" ]
sha256sum -c - <<'HASHES'
584adabecb30f487dae3db0c1ac612f9be756b3fcb08411962fa21faddfb5691  /tmp/gta4l-upload/wlfw-gta4l-1.0-r0.apk
3a5198270cba576739c4688501bcb296b075c98fe75136c7f54b85ac0339d2ef  /tmp/gta4l-upload/device-samsung-gta4l-1-r13.apk
2d3ee273780940d16289bc8b56a0a7f0d755645ed82466e59199ca3e6d31ff9d  /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r13.apk
154091de7ece08d8d19a6960acce66e4d022bfd3d0547c5401c9bc133e76626b  /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r13.apk
252dd89efbb587c93c717a00fb577359d9f1ba8b8b53ea6c605d5775a23131f8  /tmp/gta4l-upload/polkit.confd
HASHES
test -f /etc/conf.d/polkit
test ! -L /etc/conf.d/polkit
current=$(sha256sum /etc/conf.d/polkit | cut -d' ' -f1)
case "$current" in e3692b1e990fb6af9daf4fd54b875628e10c994af393969f3db621d1d6528c1b|252dd89efbb587c93c717a00fb577359d9f1ba8b8b53ea6c605d5775a23131f8) ;; *) echo 'Unrecognized Polkit configuration; refusing overwrite' >&2; exit 1;; esac
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/wlfw-gta4l-1.0-r0.apk /tmp/gta4l-upload/device-samsung-gta4l-1-r13.apk /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r13.apk /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r13.apk
install -m 0644 /tmp/gta4l-upload/polkit.confd /etc/conf.d/polkit
rc-update -q add gta4l-wlan default
/usr/libexec/rc/bin/rc-depend -u
rc-service gta4l-wlan start
[ "$(boot_hash)" = "$expected" ]
echo 'Automatic WLAN startup and Polkit configuration installed; existing boot image verified unchanged.'
