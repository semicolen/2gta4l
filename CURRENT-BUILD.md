# SM-T505 current local build — 17 October 2026

Live GNOME development now adds standard rear/front PipeWire camera sources,
working internal microphone capture, and automatic GPS orbit assistance. The user
confirmed standard Camera previews/photos/orientation and clear voice recording
and playback. A native eight-second test video has both video and microphone
audio; no images, recordings or coordinates were copied into public sources.
Snapshot 51.0-r1 fixes the reproduced shutter-player/photo crash sequence and is
installed as a signed package. Eight front JPEGs, repeated rear photos and shutter
sounds pass, and the user confirms QR scanning. The r14 recipe includes these
new packages and fingerprints their sources. GNOME Desktop and GNOME Mobile r14
are built and locally verified; fresh installation QC remains pending. Historical r13 images
do not contain these live additions. See AUDIO-REPORT.md, CAMERA-REPORT.md and
GPS-REPORT.md for evidence and remaining checks.

Desktop quality control is now in progress. The tablet has been moved from the
historical Xfce installation below to GNOME Desktop; current observations and
runtime corrections are tracked in `UI-QC.md`. Its clean installers are built
through `UI-BUILDS.md`. The original working installation is preserved in the
verified offline backup; the r4 details below remain a historical snapshot.

The corrected GNOME QC installation uses kernel #11 and SensorProxy 3.9-r4,
built locally in WSL. The actual compositor uses private Zink/Turnip on Adreno.
Earlier rotation, input, display wake, Wi-Fi, audio and custom-camera checks pass.
Fresh r12 exposed GTK 4 app crashes: selecting GTK's OpenGL renderer fixes
Settings, Files, Calculator and Terminal after reboot. Kernel #11 also fixes
GLib reporting existing files as missing. Native permission, symlink, descriptor,
legacy-access, GLib and ARM32 compatibility tests pass; all 37 driver modules,
DTBs and the ramdisk remain identical to #10. The user confirms desktop, apps,
rotation, touch and keyboard after its boot-only update. The additional account
also logs in after receiving its approved hardware groups.

Both GNOME Desktop and GNOME Mobile r13 installers are now built and locally
verified with those fixes. Desktop r13 installed through OrangeFox with matching
boot readback and unchanged recovery, and quickUser was restored. First normal
boot, fresh package/session-wrapper checks, GLib file checks and GPU device
permissions pass. Visual login and the later microphone tests pass; Mobile r13
has not been flashed.
quickUser's requested private backup
and the original full-system backup are verified. A normal restart occurred
while stopping the active GNOME session for recovery; retrying from the greeter
entered recovery successfully. The cause is not established. The live PipeWire
adapter above resolves generic camera discovery; the separately logged Firefox
GPU fault remains unresolved.

The new six-UI r5 candidate workflow is described in `UI-BUILDS.md`. It uses
device r23, which separates the Xfce screensaver dependency from the shared
hardware package. The r4 receipts below remain a historical packaging snapshot;
the packaging snapshot below uses the tested package versions listed here.

The historical Xfce installation used kernel #9, device r21, camera 1.0-r2,
GPS 1.0-r3 and audio 1.0-r3.
Rotation, standalone/desktop GPS, rear/front preview, corrected camera colors,
full-resolution photo saving and preview restart pass. Both complete native
photo paths also pass after reboot. Photos remain on the tablet.

The refreshed clean-install candidate is
`artifacts/postmarketOS-SM-T505-OrangeFox-bringup-r4.zip` (762,865,205 bytes).
It includes device r22, camera r2, GPS r3, audio r3, the rotation/sensor packages and
the matching stock firmware. Device r22 makes fresh installation disable the
obsolete upstream firmware server and earlier GPS preparation service, as the
upgrade hook already does. The backed-up Xfce installation used device r21.

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
wsl -d Ubuntu -u root --exec python3 '/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os/tools/build-current-rootfs.py'
wsl -d Ubuntu -u root --exec python3 '/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os/tools/build-current-recovery-source.py'
wsl -d Ubuntu -u root --exec python3 '/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os/tools/package-current-recovery.py'
wsl -d Ubuntu -u root --exec python3 '/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os/tools/record-provenance.py'
```

The following remaining checks describe the historical Xfce build above;
current GNOME camera, microphone and GPU results are recorded at the top of this
report and in `UI-QC.md`.

Battery reporting and the growing charge-time estimate have been audited;
the connected computer's 500 mA USB limit leaves little charging power with
the screen on. See `BATTERY-REPORT.md`. Wall charging, full-charge termination,
runtime and suspend remain unverified. Camera recording, generic V4L2/PipeWire
camera access and microphone/headset routing also remain unverified. Mobile
data is user-confirmed working with a phone SIM on 13 October 2026; see
`LTE-REPORT.md`. Calls and SMS remain unverified. Desktop OpenGL uses software
rendering; the isolated Turnip driver passes hardware Vulkan tests.
