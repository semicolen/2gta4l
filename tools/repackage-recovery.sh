#!/usr/bin/env bash
# Reuse the locally built kernel/rootfs while updating only recovery scripts.
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WORKSPACE/tools/check-recovery-preflight.py"
python3 "$WORKSPACE/tools/test-recovery-installer.py"
bash "$WORKSPACE/tools/test-recovery-image.sh"
python3 "$WORKSPACE/tools/package-recovery.py" "$ROOT/work/chroot_buildroot_aarch64/var/lib/postmarketos-android-recovery-installer/pmos-samsung-gta4l.zip" "$ROOT/postmarketOS-SM-T505-OrangeFox-bringup-r2.zip"
cp "$ROOT/postmarketOS-SM-T505-OrangeFox-bringup-r2.zip" "$WORKSPACE/artifacts/"
python3 "$WORKSPACE/tools/record-provenance.py"
cd "$WORKSPACE/artifacts"
sha256sum boot.img postmarketOS-SM-T505-OrangeFox-bringup-r2.zip apks/*.apk > SHA256SUMS
sha256sum -c SHA256SUMS
stat -c '%n %s bytes' postmarketOS-SM-T505-OrangeFox-bringup-r2.zip
