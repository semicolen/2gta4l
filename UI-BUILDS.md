# SM-T505 desktop image builds

Six separate postmarketOS edge root filesystems are built locally in WSL Ubuntu:
Xfce, KDE Plasma Mobile, KDE Plasma Desktop, GNOME Mobile, GNOME Desktop, and
Sxmo with Sway. Each uses the downstream kernel #9 and its exact 37 modules,
matching SM-T505 firmware, device package r23, camera r2, GPS r3 and audio r3.
The tablet's currently installed Xfce system is not changed by this build process.

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
| `plasma-desktop` | Wayland | SDDM | CPU OpenGL and Qt Quick software rendering |
| `gnome-mobile` | Wayland | GDM | CPU OpenGL rendering |
| `gnome` | Wayland | GDM | CPU OpenGL rendering |
| `sxmo-de-sway` | Wayland | tinydm/seatd | Pixman renderer |

OpenRC and the tested PulseAudio backend are retained in every profile. Device
r23 puts the patched Xfce screensaver in an Xfce-only subpackage, so the other
desktops do not install it. The Xfce rotation helper only starts in Xfce; native
Wayland desktops use their own output/input handling. The Sxmo candidate has a
DSI-1 portrait transform and touchscreen-to-output mapping in its Sway config.
The two Plasma profile recipes retain their existing OpenRC hooks and add a
downstream OpenRC metadata option; the build does not use the systemd repository.

Successful image assembly does not establish that a new desktop works on this
downstream DRM driver. The fresh images have not been flashed. Native Wayland
login, panel orientation, touch mapping, automatic rotation, screen wake,
on-screen keyboards and camera windows require tablet testing for each UI.
The previously verified Xfce results apply to the installed system. The separate
Turnip/KGSL Vulkan test does not establish accelerated desktop OpenGL support.
Use the port's `gta4l-camera` application for the Samsung camera HAL. Generic
V4L2 camera applications included by a desktop profile do not use this bridge.
The bridge's automatic photo orientation currently follows the Xfce rotation
status; equivalent orientation tracking in native Wayland sessions remains work
for their tablet tests.
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
wsl -d Ubuntu -u root --exec bash '/mnt/c/postmarketOS-gta4l/tools/build-ui-device.sh'
wsl -d Ubuntu -u root --exec python3 '/mnt/c/postmarketOS-gta4l/tools/build-ui-variants.py' --resume
```

To build one profile, add `--ui plasma-mobile` (or another profile listed above).
The batch uses isolated work directories under `/home/pmos/sm-t505-port/ui-work/`,
with shared download caches and built APKs. A completed image is skipped only
after its stored size and SHA256 match. No tablet connection or flash command is
part of the batch. Build logs stay under `logs/ui-builds/` and may contain private
build settings; generated installers and credentials are excluded from Git.
