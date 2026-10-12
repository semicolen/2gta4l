#!/bin/sh
set -eu
expected=faf5a4a554ffa5b01f2adc92b5fee47719e46b5db4542b3b42be225d451cebef
boot_hash() { head -c 28934160 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = "$expected" ]
sha256sum -c - <<'HASHES'
2e68345c10bd07264ab76bdd306bdc189d9499e50e7a9acded4dfed96c57f160  /tmp/gta4l-upload/tqftpserv-gta4l-1.2-r0.apk
8927083b23a11158f309a4b4b011d0bf8a4a360870559df7a78aa9aeef1e10a9  /tmp/gta4l-upload/device-samsung-gta4l-1-r12.apk
c6b870b186371256d85755314dd1425d6c7941972f926f39d5e8f7de553393b3  /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r12.apk
9a1be12a68c9a1235f6b2e18342af7de9184874c36577fbb16a094a7cb23b0b8  /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r12.apk
HASHES
# OpenRC also stops the two firmware consumers before removing their provider.
rc-service tqftpserv stop
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/tqftpserv-gta4l-1.2-r0.apk /tmp/gta4l-upload/device-samsung-gta4l-1-r12.apk /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r12.apk /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r12.apk
rc-update -q del tqftpserv default 2>/dev/null || true
rc-update -q add gta4l-tqftpserv default
rc-update -q add gta4l-dbus-services default
/usr/libexec/rc/bin/rc-depend -u
rc-service gta4l-tqftpserv start
rc-service gta4l-adsp start
rc-service gta4l-modem start
rc-service gta4l-ipa start
[ "$(boot_hash)" = "$expected" ]
echo 'Installed local downstream firmware server; existing boot image verified unchanged.'
