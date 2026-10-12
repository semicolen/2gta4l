#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
mkdir -p "$WORKSPACE/artifacts" "$WORKSPACE/logs"
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/sync-port.sh" build --lax linux-samsung-gta4l --arch aarch64
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/kernel-build.log"
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/sync-port.sh" build --lax qrtr-ns-gta4l pd-mapper-gta4l tqftpserv-gta4l wlfw-gta4l alsa-ucm-gta4l bluetooth-gta4l firmware-samsung-gta4l device-samsung-gta4l --arch aarch64
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/packages-build.log"
if [ ! -f "$ROOT/initial-password" ]; then
    umask 077
    openssl rand -hex 12 > "$ROOT/initial-password"
fi
password="$(cat "$ROOT/initial-password")"
printf 'Temporary test login\nUser: tablet\nPassword: %s\nChange this password after boot.\n' "$password" > "$WORKSPACE/artifacts/initial-login.txt"
bash "$WORKSPACE/tools/pmb.sh" install --no-image --password "$password" --add device-samsung-gta4l-nonfree-firmware
python3 "$WORKSPACE/tools/verify-rootfs.py"
bash "$WORKSPACE/tools/pmb.sh" install --android-recovery-zip --recovery-install-partition userdata --password "$password" --add device-samsung-gta4l-nonfree-firmware
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/image-build.log"
python3 "$WORKSPACE/tools/verify-initramfs.py"
bash "$WORKSPACE/tools/pmb.sh" export
cp "$ROOT/work/chroot_rootfs_samsung-gta4l/boot/boot.img" "$WORKSPACE/artifacts/boot.img"
python3 "$WORKSPACE/tools/verify-boot.py" "$WORKSPACE/artifacts/boot.img" "$WORKSPACE/artifacts/boot-verification.json"
python3 "$WORKSPACE/tools/package-recovery.py" "$ROOT/work/chroot_buildroot_aarch64/var/lib/postmarketos-android-recovery-installer/pmos-samsung-gta4l.zip" "$ROOT/postmarketOS-SM-T505-OrangeFox-bringup-r2.zip"
cp "$ROOT/postmarketOS-SM-T505-OrangeFox-bringup-r2.zip" "$WORKSPACE/artifacts/"
python3 "$WORKSPACE/tools/record-provenance.py"
cd "$WORKSPACE/artifacts"
sha256sum boot.img postmarketOS-SM-T505-OrangeFox-bringup-r2.zip apks/*.apk > SHA256SUMS
