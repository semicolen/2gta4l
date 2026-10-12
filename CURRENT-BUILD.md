# SM-T505 current local build — 12 October 2026

The tablet runs the tested kernel #9, device r21, camera 1.0-r2, GPS 1.0-r3 and audio 1.0-r3.
Rotation, standalone/desktop GPS, rear/front preview, corrected camera colors,
full-resolution photo saving and preview restart pass. Both complete native
photo paths also pass after reboot. Photos remain on the tablet.

The refreshed clean-install candidate is
`artifacts/postmarketOS-SM-T505-OrangeFox-bringup-r4.zip` (762,865,205 bytes).
It includes device r22, camera r2, GPS r3, audio r3, the rotation/sensor packages and
the matching stock firmware. Device r22 makes fresh installation disable the
obsolete upstream firmware server and earlier GPS preparation service, as the
upgrade hook already does. The currently running tablet remains on device r21.

This ZIP is a **clean installer that formats userdata and replaces boot**.
It is not an incremental update for the working tablet. It preserves OrangeFox,
DTBO, super, modem firmware, EFS, persist and the bootloader. It has not been
flashed; the refreshed rootfs's first boot remains unverified. Its kernel,
ramdisk, DTBs and boot header are byte-identical to the currently tested boot.

Local checks verify all 37 embedded kernel modules against the tested kernel,
the actual rootfs APK versions, 17 enabled device/desktop services, 10 firmware
PD maps, 15 early touch firmware files, ZIP CRCs and the installer guards that
stop before formatting on a wrong target, busy userdata or failed mapping.

SHA256:

```text
ec0f6ab16b6b9e4859d51dd3248454d43e7f403f44a3de6b41f5456d4db90864  postmarketOS-SM-T505-OrangeFox-bringup-r4.zip
4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663  boot-current.img
```

Use OrangeFox sideload or external SD/USB media for a future clean installation.
The ZIP must remain outside userdata while installation formats that partition.
The private `artifacts/initial-login.txt` contains the candidate's login details.
Audio r3 fixes rough startup with interrupt scheduling on the internal card.
Cold-start 48/44.1 kHz playback passes after an audio-server restart, and the
user confirms smooth incoming Bluetooth audio. Normal reboot with this
policy remains unverified; see `AUDIO-REPORT.md`.

Current build and installer reports are in `artifacts/current-build-verification.json`
and `artifacts/installer-current-verification.json`; checksums are also in
`artifacts/SHA256SUMS-current`.

Rebuild each stage sequentially in WSL Ubuntu, waiting for it to finish before
starting the next:

```powershell
wsl -d Ubuntu -u root --exec python3 '/mnt/c/postmarketOS-gta4l/tools/build-current-rootfs.py'
wsl -d Ubuntu -u root --exec python3 '/mnt/c/postmarketOS-gta4l/tools/build-current-recovery-source.py'
wsl -d Ubuntu -u root --exec python3 '/mnt/c/postmarketOS-gta4l/tools/package-current-recovery.py'
wsl -d Ubuntu -u root --exec python3 '/mnt/c/postmarketOS-gta4l/tools/record-provenance.py'
```

Battery reporting and the growing charge-time estimate have been audited;
the connected computer's 500 mA USB limit leaves little charging power with
the screen on. See `BATTERY-REPORT.md`. Wall charging, full-charge termination,
runtime and suspend remain unverified. Camera recording, generic V4L2/PipeWire
camera access and microphone/headset routing also remain unverified. LTE modem discovery works,
but mobile data needs an active plan to validate. Desktop OpenGL uses software
rendering; the isolated Turnip driver passes hardware Vulkan tests.
