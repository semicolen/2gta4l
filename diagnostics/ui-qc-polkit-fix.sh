#!/bin/sh
set -eu
printf '%s\n' \
 '10fa9e9db01e9ee9b32c934de361e0f05a0db18d12f7a333a931fe7470e29e4a  /tmp/gta4l-upload/polkit-elogind-127-r3.apk' \
 '114a710596ba1530c5257375640a661fd2a366c12d65e7b2b0fb6ac8068fdb2b  /tmp/gta4l-upload/polkit-elogind-libs-127-r3.apk' | sha256sum -c -
mkdir -p /var/lib/gta4l-ui-qc
cp /etc/apk/world /var/lib/gta4l-ui-qc/world-before-polkit-fix
apk add --no-network /tmp/gta4l-upload/polkit-elogind-127-r3.apk \
    /tmp/gta4l-upload/polkit-elogind-libs-127-r3.apk gnome-keyring gcr
apk info -e polkit-elogind
apk info -e polkit-elogind-libs
if apk info -e polkit-noelogind-libs >/dev/null; then
    printf 'Wrong Polkit libraries remain installed\n' >&2
    exit 1
fi
rc-service polkit restart
rc-service tinydm restart
printf '\nPOLKIT_ELOGIND_CORRECTION_END\n'
