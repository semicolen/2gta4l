#!/bin/sh
set -eu
boot_hash() { head -c 28934160 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = 'faf5a4a554ffa5b01f2adc92b5fee47719e46b5db4542b3b42be225d451cebef' ]
sha256sum -c - <<'HASHES'
a32afa09ae09ef660244b9d9a408bafbe7ed780dbe22556d4013af85d226c93d  /tmp/gta4l-upload/bluetooth-gta4l-1.0-r0.apk
7540fdcd2739438a506c953fc6857e83cc2665efdfc9c18ecd7d903cb06790c9  /tmp/gta4l-upload/device-samsung-gta4l-1-r15.apk
fcfd5cbaa94df8f4332db6674067187358958f600724eb9647174a43a53d9400  /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r15.apk
105882445c3846d328d7baf258a06bafe6198325a19fe7710576e646f4842b36  /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r15.apk
f9c504f881797d2ef1bcbae110af0517b445b1296c0c50e8bf095284f137fefd  /tmp/gta4l-upload/linux-samsung-gta4l-4.19.300-r8.apk
HASHES
apk info -e python3 bluez e2fsprogs-extra firmware-samsung-gta4l alsa-ucm-gta4l networkmanager-bluetooth
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/bluetooth-gta4l-1.0-r0.apk /tmp/gta4l-upload/device-samsung-gta4l-1-r15.apk /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r15.apk /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r15.apk /tmp/gta4l-upload/linux-samsung-gta4l-4.19.300-r8.apk
rc-update -q add gta4l-bluetooth default
/usr/libexec/rc/bin/rc-depend -u
[ "$(boot_hash)" = 'faf5a4a554ffa5b01f2adc92b5fee47719e46b5db4542b3b42be225d451cebef' ]
echo BLUETOOTH_AND_KERNEL9_PACKAGES_INSTALLED_BOOT_UNCHANGED
