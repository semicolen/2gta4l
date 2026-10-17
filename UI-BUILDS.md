# SM-T505 desktop image builds

The r14 images include audio UCM r4 (verified internal microphone),
GPS/ModemManager r5, the on-demand GPS assistance service, and standard PipeWire
camera sources for GNOME/KDE. GNOME also pins the targeted Snapshot shutter-player
patch. Its signed package and tablet photo regression pass, including repeated
shutter sounds. GNOME Desktop and GNOME Mobile r14 are now built and locally
verified. Both preserve the tested #11 boot and exact 37 driver modules, include
the expected package database and signing keys, and pass the rootfs checks.
They have not yet been flashed for fresh-install QC. Historical r13 installers
retain the previous stack.

For the user's final package, use GNOME Desktop, the profile tested on the
tablet. `tools/package-gnome-release.py` stages its unchanged r14 OrangeFox ZIP,
installation notes, receipts and checksums in
`artifacts/releases/SM-T505-GNOME-Desktop-r14/`. The embedded first-boot
configuration is checked before staging. This package retains GDM login with
the pre-created `tablet` account; it does not enable the separate Nura installer
profile. See `FIRST-BOOT.md` for the setup decision and installation steps.

| Local r14 installer | Bytes | SHA256 |
| --- | ---: | --- |
| `postmarketOS-SM-T505-OrangeFox-gnome-r14.zip` | 1,057,668,706 | `2947a1934f40ea92e29f745a488e6ec94e891867000a3518966d305925fa71bc` |
| `postmarketOS-SM-T505-OrangeFox-gnome-mobile-r14.zip` | 1,060,174,998 | `cf186d8ba6cc0d1f12066bf19ed31d293ec6d74665cc201b1936b255c52e2808` |

Six separate postmarketOS edge root filesystems are built locally in WSL Ubuntu:
Xfce, KDE Plasma Mobile, KDE Plasma Desktop, GNOME Mobile, GNOME Desktop, and
Sxmo with Sway. The original builds use downstream kernel #9 and its exact 37
modules, matching SM-T505 firmware and device package r23. The r12 workflow uses
tested kernel #10, with identical driver modules, and SensorProxy 3.9-r4's
early-claim sampling correction. The original r5 candidates use
camera r2, GPS r3 and audio r3. The corrected r10 desktop workflow uses camera r5
with native Wayland orientation tracking and the same GPS/audio packages.
Building these files does not flash the tablet. The current installation and
the user's quality-control observations are recorded in `UI-QC.md`.

The locally verified r13 GNOME installers add a session wrapper selecting GTK's OpenGL
renderer on the private Adreno stack. The corresponding live fix passes the
user's Settings, Files, Calculator and Terminal checks after reboot. Both also
include tested kernel #11 (APK 4.19.300-r10), whose faccessat2 backport fixes
GLib file-existence checks. Native permission and ARM32 compatibility tests pass,
with all 37 driver modules, DTBs and ramdisk unchanged. GNOME Desktop r13 is
entering clean-install QC; GNOME Mobile r13 awaits its first tablet installation.

The build output is `artifacts/ui-builds/`. `index.json` contains the completed
packages, their sizes and verification status; `SHA256SUMS` contains their hashes.
Each UI also has a rootfs verification report and installer verification report.

## Installation scope

These are **clean OrangeFox installers that erase userdata and replace boot**.
They preserve OrangeFox, DTBO, super, modem firmware, EFS, persist and the
bootloader. Use OrangeFox sideload or keep the ZIP on external SD/USB storage;
the installer cannot safely read a ZIP from the userdata partition it formats.
See `INSTALL.md` for the existing model/partition checks and installation workflow.
Login credentials are in the private `artifacts/initial-login.txt`.

## Desktop differences

| Profile | Session | Login service | Rendering |
| --- | --- | --- | --- |
| `xfce4` | X11 | LightDM | Tested modesetting configuration, CPU rendering |
| `plasma-mobile` | Wayland | tinydm | CPU OpenGL and Qt Quick software rendering |
| `plasma-desktop` | Wayland | SDDM | Adreno 610 via Zink/Turnip; software greeter and fallback |
| `gnome-mobile` | Wayland | GDM | Adreno session candidate in r12; runtime QC pending |
| `gnome` | Wayland | GDM | Adreno via Zink/Turnip in r12; software greeter and fallback |
| `sxmo-de-sway` | Wayland | tinydm/seatd | Pixman renderer |

OpenRC and the tested PulseAudio backend are retained in every profile. Device
r23 puts the patched Xfce screensaver in an Xfce-only subpackage, so the other
desktops do not install it. The Xfce rotation helper only starts in Xfce; native
Wayland desktops use their own output/input handling. The Sxmo candidate has a
DSI-1 portrait transform and touchscreen-to-output mapping in its Sway config.
The two Plasma profile recipes retain their existing OpenRC hooks and add a
downstream OpenRC metadata option; the build does not use the systemd repository.

Successful image assembly does not establish that a new desktop works on this
downstream DRM driver. The fresh Xfce image passed basic installation, boot and
input checks; results for each image are recorded in `UI-QC.md`. Native Wayland
login, panel orientation, touch mapping, automatic rotation, screen wake,
on-screen keyboards and camera windows require tablet testing for each UI.
The previously verified Xfce results apply to the installed system. The separate
Turnip/KGSL Vulkan test alone does not establish accelerated desktop OpenGL
support. Plasma Desktop now also passes an accelerated KWin reboot and physical
wake, rotation, input and camera checks; see `GPU-REPORT.md`. The r10 Plasma
installer includes the exact tested private Mesa 26.0.8-r3 runtime and session
configuration. Its rebuilt clean installation still requires its own QC.
Use the port's `gta4l-camera` application for the Samsung camera HAL. Generic
V4L2 camera applications included by a desktop profile do not use this bridge.
Camera r2 follows the Xfce rotation status. Camera r5 also reads the standard
Wayland output transform for preview and photo orientation, retaining the Xfce
path for X11. Each desktop's camera behavior still requires its own tablet check.
The assembled GNOME desktop uses shell/Mutter 51, while GNOME Mobile uses the
patched 48 series. Both currently select pmaports' OpenRC-compatible
`gnome-session` 48 package. Their component versions are recorded in the index;
successful dependency resolution does not verify this session combination at
runtime.

## Rebuilding locally

The existing local source trees, stock firmware extraction, built port APKs,
tested `boot-current.img`, its module verification manifest and the audited
recovery template are prerequisites. See `CURRENT-BUILD.md` for that baseline.
The older `package-current-recovery.py` helper records the r4/device-r22 snapshot;
use this UI workflow for the new device-r23 candidates.
Build the UI-neutral device package first, then run the resumable batch:

```powershell
wsl -d Ubuntu -u root --exec bash '/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os/tools/build-ui-device.sh'
wsl -d Ubuntu -u root --exec bash '/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os/tools/build-zink-kgsl-package.sh'
wsl -d Ubuntu -u root --exec python3 '/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os/tools/build-ui-variants.py' --resume
```

To build one profile, add `--ui plasma-mobile` (or another profile listed above).
The batch uses isolated work directories under `/home/ark/sm-t505-port/ui-work/`,
with shared download caches and built APKs. A completed image is skipped only
after its stored size and SHA256 match. No tablet connection or flash command is
part of the batch. Build logs stay under `logs/ui-builds/` and may contain private
build settings; generated installers and credentials are excluded from Git.

The corrected recipe also verifies a source fingerprint before skipping a completed
image. It selects the elogind Polkit provider for every UI, supplies the tested
KWin touch calibration to both Plasma profiles, and retains the base RNDIS gadget
instead of starting the mobile USB controller. Plasma Mobile's runtime fixes
were checked on the tablet; each rebuilt desktop still requires its own QC.
The r10 recipe includes separate SDDM greeter calibration, Plasma's native tablet
mode and the measured native Wayland sensor axes. Xfce keeps its existing sensor
rule. Camera r5 handles native output rotation and suppresses a false stop error
during the transition from a completed photo back to preview.
The r12 recipe selects the private GPU runtime for Plasma Desktop and both
GNOME profiles. Plasma Desktop and GNOME Desktop's actual compositors pass
hardware checks; GNOME Mobile remains a test candidate. The other profiles
retain their existing rendering settings.
The r11 recipe adds a GNOME-only Himax libinput calibration after the device's
Xfce identity rule. It applies to GDM and the user session in both GNOME profiles.
The override is verified in udev on the running GNOME Desktop; physical input
validation has passed on GNOME Desktop. The completed r10 GNOME images predate this fix.
The r11 GNOME Mobile installer has completed local assembly checks. It predates
the kernel #10 input/API fixes and SensorProxy 3.9-r4 early-claim correction.
GNOME Desktop's runtime now passes rotation, input, wake, network, audio and
custom-camera checks with Adreno rendering. Its r12 installer is locally verified
and exposed a GTK 4 app-launch failure on first boot. The r13 GNOME installers
carry the tested OpenGL session correction and kernel #11; both pass local
assembly and receipt verification. Their fresh runtime checks are tracked in
UI-QC.md. The verified
kernel #9 rollback image is retained separately from the new build input.
