# SM-T505 GNOME Desktop r15

Downstream Nura/postmarketOS build for the Samsung Galaxy Tab A7 LTE **SM-T505**.
GNOME Desktop is the tablet-tested profile; this is not the separate GNOME Mobile
profile. Built and packaged locally in WSL Ubuntu.

## Login

- Username: `user`
- Password: `147147`

These are the [documented default credentials](https://postmarketos.org/download/).
Change the password after first login with `passwd`. The first boot uses the
normal GNOME login screen; this image does not enable an account-setup wizard.

This public image derives from the locally verified r14 image. It changes the
default account, removes account backups, build logs/cache and generated machine
identity, and excludes SSH host keys and personal network credentials. The
kernel, driver modules, firmware, installed packages and desktop fixes retain
their verified contents. Host keys and machine identity are generated on boot.

## Install

**Installation erases userdata and replaces boot. Back up files first.**
Use OrangeFox recovery with an unlocked bootloader on **SM-T505 only**. The
installer checks the model and partition layout. It preserves recovery, DTBO,
super, modem firmware, EFS, persist and the bootloader.

Verify the ZIP against `SHA256SUMS`. Copy it to external SD/USB storage and
install it in OrangeFox, or select ADB Sideload and run:

```text
adb sideload Nura-SM-T505-OrangeFox-GNOME-Desktop-r15.zip
```

Wait for the successful completion message. Tap Cancel/Back if sideload mode
remains open, then select Reboot -> System. Log in with the credentials above.
The ZIP cannot be installed from the internal userdata partition it formats.

## Status

This is a **prerelease**. The underlying running GNOME Desktop installation has
passed checks for Adreno rendering, all four rotations, touch, the on-screen
keyboard, display wake, Wi-Fi, speakers, microphone and both camera apps.
Repeated camera photos with shutter sound, video voice recording and QR scanning
pass. LTE data, Bluetooth and SD-card results are recorded in the repository's
`PORT-STATUS.md` and `UI-QC.md`.

The public image passes local account/password, boot, module, package, payload
integrity, privacy and installer checks. A clean flash of r15 has not yet been
tested on the tablet. Maps location delivery latency, extended camera stability,
calls/SMS and full system suspend remain open checks. Use the supplied checksum
and verification manifest to identify this build.

A separately observed Firefox GPU fault and native GTK Vulkan presentation are
also unresolved. GNOME apps use the tested OpenGL renderer.

The source and downstream patches are in the repository's `downstream` branch.
The repository's existing AI merge-policy notice remains applicable.
