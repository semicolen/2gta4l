# SM-T505 GNOME Desktop r14

This package uses the GNOME Desktop profile tested on the tablet. GNOME Mobile
is a separate image and has not completed tablet quality control.

## First boot

After OrangeFox installation, reboot into System. The expected first screen is
the GNOME login screen. Sign in as `tablet` using this workspace's private
`artifacts/initial-login.txt`. The installer creates a fresh home directory;
existing accounts, settings, photos and recordings are not included in the ZIP.
Restoring the requested `quickUser` account during development is a separate
operation using its private backup.

This release retains the existing login flow. It does not enable a Nura
account-creation wizard. Both GNOME images contain `gnome-initial-setup`, but the
image already has the `tablet` account. The separate upstream
`postmarketos-ui-os-installer` profile explicitly requires systemd and performs
an installation using pmbootstrap; its default configuration selects a disk,
not an existing partition. This port uses OpenRC and the guarded OrangeFox
installer targeting userdata. Following the user's fallback, this package does
not replace that tested installation path with the separate installer profile.

## Install with OrangeFox

This is a **clean installer: it erases userdata and replaces boot**. Back up any
files to keep. It preserves recovery, DTBO, super, modem firmware, EFS, persist
and the bootloader. The package is only for the Samsung Galaxy Tab A7 SM-T505.

Keep the ZIP on an external SD card or USB storage, then select it in OrangeFox,
or choose ADB Sideload in OrangeFox and run:

```powershell
adb sideload postmarketOS-SM-T505-OrangeFox-gnome-r14.zip
```

Wait for the installation-complete message. If recovery remains in sideload
mode, tap Cancel/Back, then choose Reboot -> System. A ZIP stored on internal
userdata cannot be used as the source while that partition is being formatted.

The release folder contains `SHA256SUMS`, the build receipts and a release
manifest. Its ZIP is byte-for-byte identical to the locally verified r14 image.

## Verification status

The running GNOME Desktop installation passes the recorded checks for Adreno
rendering, rotation, touch, keyboard, display wake, Wi-Fi, speakers, microphone,
and both custom and standard camera apps. Repeated standard Camera photos with
shutter sound and QR scanning pass. LTE and the other hardware results are
tracked in `PORT-STATUS.md` and `UI-QC.md`.

The r14 ZIP includes the signed fixes tested on that running installation and
passes local boot, module, package, rootfs and installer checks. A clean flash of
r14 has not yet completed tablet quality control. GPS Maps delivery latency,
extended camera stability, calls/SMS and full system suspend remain open checks.
