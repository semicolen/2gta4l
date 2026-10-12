# postmarketOS downstream port for Samsung Galaxy Tab A7 LTE (SM-T505)

Local port based on [semicolen/2gta4l](https://github.com/semicolen/2gta4l/tree/downstream),
using the matching stock `T505XXS8CXG1` firmware and
[OrangeFox SM-T505](https://github.com/semicolen/orangefoxrecovery-sm505).
See [PORT-STATUS.md](PORT-STATUS.md) for the current validation boundary.
See [CURRENT-BUILD.md](CURRENT-BUILD.md) for the refreshed local OrangeFox r4
clean-install candidate and checksums. Its rootfs has not been flashed.

This branch publishes the current source recipes, patches, runtime helpers,
OrangeFox installer code and hardware reports. The original three package
directories now live under `port/` alongside the additional device packages.
Build receipts and pinned upstream revisions are under `validation/`.
Compiled images, stock firmware/runtime archives, credentials and raw device
captures are local inputs/outputs. See [BUILD-SETUP.md](BUILD-SETUP.md) before
using the developer scripts in a new workspace.

**This is bring-up work. Full device functionality is not established by a
successful build.** Automatic graphical login, Xfce and calibrated touch work.
An isolated Turnip KGSL driver passes hardware Vulkan compute and graphics tests;
desktop OpenGL remains software rendered. Bounded display wake tests pass.
Wi-Fi initializes and reconnects automatically, with DHCP, DNS, ping, and
certificate-validated HTTPS verified after reboot. Speaker playback now passes
ALSA and desktop audio tests. Audio r3 fixes rough startup with interrupt
scheduling; cold starts pass at 48/44.1 kHz after an audio-server restart,
and incoming Bluetooth audio is user-confirmed smooth from the start.
Bluetooth initializes automatically; the BLE mouse works after reboot, and
laptop Bluetooth tethering passes directly bound DNS and HTTPS tests.
Automatic rotation and aligned touch work in all four positions, including
after reboot and while locked. Standalone GPS and desktop GeoClue location
requests pass after reboot, with gathering stopped when the client closes.
Rear/front camera preview and lens switching work at 640×480,
including preview rotation in all four positions. Camera r2 captures full-size
3264×2448 rear and 2592×1944 front photos and corrects chroma order. Native
photo saving, preview restart and correct colors pass. Camera recording,
LTE data, microphone/headset routing, charging, suspend and remaining
sensors need further work.

## Merge info ##
This repo is not legiable to be merged to Nura (Formerly known as postmarket os) due to the ai policy seen [here](https://docs.nura.eco/policies-and-processes/development/ai-policy.html).
Do not intentionally upload it, merge it or contribute code with the fact stated.

## Layout

- `port/`: downstream device, kernel and local firmware APKBUILDs.
- `tools/`: WSL setup, firmware extraction, build and verification helpers.
- `validation/`: public packaging receipts and pinned source revisions.
- `evidence/`: private local ADB/stock observations; excluded from Git.
- `firmware-local/`: locally extracted proprietary firmware; excluded from Git.
- `artifacts/`: generated images, source manifest and backups; excluded from Git.
- Native WSL sources and build chroots: `/home/pmos/sm-t505-port`.

Kernel: Linux 4.19.300, pinned LineageOS commit
`381a5549ee66fa751f632ee0840f5631274209ee`. Vendor display, camera, GPU, charger,
thermal, storage, touchscreen and networking drivers are retained. Loadable
audio and WLAN modules are included in the kernel package. The desktop starts
with Xfce/OpenRC and DRM modesetting; desktop OpenGL uses software rendering.
See [GPU-REPORT.md](GPU-REPORT.md) and
[DISPLAY-RESUME-REPORT.md](DISPLAY-RESUME-REPORT.md) for bounded hardware results.
See [WIFI-REPORT.md](WIFI-REPORT.md) for Wi-Fi startup and authorization evidence.
See [AUDIO-REPORT.md](AUDIO-REPORT.md) for the tested speaker route and remaining audio work.
See [BLUETOOTH-REPORT.md](BLUETOOTH-REPORT.md) for radio startup, mouse and PAN results.
See [ROTATION-REPORT.md](ROTATION-REPORT.md) for sensor startup, rotation and lock-screen tests.
See [GPS-REPORT.md](GPS-REPORT.md) for satellite fixes, desktop location and reboot tests.
See [CAMERA-REPORT.md](CAMERA-REPORT.md) for verified rear/front capture and remaining integration work.

## Local build

All builds run in **WSL Ubuntu**, with chroots on the Linux ext4 filesystem.
The Windows workspace stores editable recipes and final outputs. The supplied
firmware directory is read only. No cloud builds are used.

The helper scripts currently use this machine's paths. Run from PowerShell:

```powershell
wsl -d Ubuntu -u root --exec bash '/mnt/c/postmarketOS-gta4l/tools/pmb.sh' status
wsl -d Ubuntu --exec python3 '/mnt/c/postmarketOS-gta4l/tools/configure-port.py'
wsl -d Ubuntu -u root --exec bash '/mnt/c/postmarketOS-gta4l/tools/sync-port.sh' build --lax linux-samsung-gta4l --arch aarch64
wsl -d Ubuntu -u root --exec bash '/mnt/c/postmarketOS-gta4l/tools/build-image.sh'
```

`--as-root` is confined to this dedicated pmbootstrap workspace and avoids
changing the Ubuntu user's sudo configuration. Package compilation still uses
pmbootstrap's build chroot. The stock firmware archive is prepared from AP,
BL/APNHLOS and CP containers with `extract-stock.py`, `extract-vendor-stock.sh`,
`extract-extra-firmware.py`, then `prepare-firmware.sh`.

The image builder reuses up-to-date locally built packages. It checks the
packaged driver list, enabled services, stock PD manifests, touchscreen
firmware inside the initramfs, ARM64 kernel configuration, boot header, and
the kernel embedded in the final OrangeFox ZIP. Outputs are under `artifacts/`:
the ZIP, `boot.img`, verification reports, source manifest, `SHA256SUMS`, and
`initial-login.txt`. Build logs are under `logs/`.

The Qualcomm runtime includes a locally compiled QRTR name server and a
locally compiled protection-domain mapper adapted for downstream PIL.
The modem storage service uses the retained UIO driver and read-only NV
storage for the first tests. Enabling persistent modem writes and checking
LTE data routing are subsequent device validation steps.

## Installation target

The selected target is **internal userdata + boot through OrangeFox**. (Via this OrangeFox recovery [here](https://github.com/semicolen/orangefoxrecovery-sm505)) This
replaces existing Android user data. Recovery, dynamic super partitions,
bootloader, modem partitions and device calibration partitions are not
installation targets. The device package disables pmbootstrap fastboot
flashing; partition metadata is explicitly supplied for recovery packaging.

Before the first installation, verify the artifact's checksums and boot-header
report, boot the existing OrangeFox recovery, and make backups. The helper
below only reads partitions:

```powershell
python tools\backup-recovery.py --serial <device-serial>
```

Backups include boot, recovery, DTBO, vbmeta, EFS, modem calibration and persist.
Android userdata requires a separate user backup; the helper does not copy it.

Use OrangeFox **ADB sideload** or external media for the installer ZIP.
Do not put it on internal Android storage: the installer replaces that storage
while it is still reading the ZIP. See [INSTALL.md](INSTALL.md) for the test
installation sequence and [PORT-STATUS.md](PORT-STATUS.md) for remaining work.

The historical full installer is `postmarketOS-SM-T505-OrangeFox-bringup-r2.zip`;
it predates the currently installed incremental fixes. The original installer
failed because its chroot could not see OrangeFox's mounted userdata. Revision
2 fixes the mount checks and requires successful nested partition setup before
formatting. To repackage only the installer scripts using the existing local
kernel/rootfs, run `tools/repackage-recovery.sh` as root in WSL Ubuntu.
Repackaging that snapshot does not incorporate newer APKs; a complete image
rebuild is required for a fresh installation with the latest fixes.

After a tested installation exists, replace the temporary login password and
keep the original Samsung firmware and OrangeFox recovery available locally.

## Incremental kernel bring-up

The tablet has an installed Linux filesystem. Subsequent kernel tests use
boot-only OrangeFox ZIPs and matching APK upgrades with package scripts disabled.
The helpers check the expected existing boot hash, the device identity, partition
size and final readback. They do not format userdata. The original full installer
is an earlier bring-up snapshot and does not contain these later repairs.

Kernel #7 (`4.19.300-r6`) reaches the login screen and starts SSH, ADSP/ALSA,
IPA and ModemManager automatically. Its DPMS resume still fails; a full modeset
restores the screen. Kernel #8 (`4.19.300-r7`) adds SSPP plane revalidation on
the display active transition; its first physical DPMS wake test passes. Rebuild its
kernel and guarded update locally with:

```powershell
wsl -d Ubuntu -u root --exec bash '/mnt/c/postmarketOS-gta4l/tools/build-plane-resume-kernel-fix.sh'
wsl -d Ubuntu -u root --exec python3 '/mnt/c/postmarketOS-gta4l/tools/build-plane-resume-boot-update.py'
```

The current tablet runs kernel #9 (`4.19.300-r8`) and device r21. It retains
the display repairs and adds guarded WCN3988 initialization, BNEP/HIDP modules,
and HIDRAW. Its first normal boot and Bluetooth PAN internet test pass. Build
the Bluetooth kernel package set and boot-only update locally with:

```powershell
wsl -d Ubuntu -u root --exec bash '/mnt/c/postmarketOS-gta4l/tools/build-bluetooth-port-update.sh'
wsl -d Ubuntu -u root --exec python3 '/mnt/c/postmarketOS-gta4l/tools/build-bluetooth-boot-update.py'
```
