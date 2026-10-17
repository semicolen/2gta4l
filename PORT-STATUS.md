# SM-T505 downstream postmarketOS port

This workspace derives from `semicolen/2gta4l`, downstream commit
`35b3893a62ea326fe487b0790827fc1a72717f49`. The kernel source is LineageOS
`android_kernel_samsung_sm6115`, commit
`381a5549ee66fa751f632ee0840f5631274209ee`, Linux 4.19.300.

## Device evidence

ADB identifies the attached device as **SM-T505**, codename **gta4l**,
platform **bengal**, Android 12, bootloader **T505XXS8CXG1**. Android reports
an unlocked bootloader and a 1200×2000 panel. The installed stock kernel is
4.19.157. Raw observations are saved locally under `evidence/` and excluded
from Git. Android SELinux restricts kernel logs and some firmware reads.

The matching local AP archive confirms a v2 Android boot header, 4096-byte
pages, kernel address `0x8000`, ramdisk address `0x02000000`, tags address
`0x01e00000`, DTB address `0x01f00000`, and board `SRPTC24A008`. These match
the supplied OrangeFox source, commit
`e820bb63df247510bdd150bca28e1365f92faf05`.

Boot is `/dev/block/mmcblk0p69` (96 MiB). Recovery is
`/dev/block/mmcblk0p70`. Userdata is `/dev/block/mmcblk0p80` (about 21.9 GiB).
The intended installation target is **boot + userdata**, selected by the
user. Installing there destroys existing Android user data. Source preparation
and local builds do not write the tablet's partitions.

## Changes being built

- Correct v2 boot packaging, DTB payload, ramdisk offset, and board name.
- Package all locally compiled vendor modules; the original helper packaged
  only the kernel image. Audio and WLAN require loadable modules.
- Enable Linux userspace requirements, framebuffer emulation and USB ECM/RNDIS.
- Include the QRTR userspace name server needed by the older downstream kernel,
  a PD mapper that reads the stock `.jsn` manifests directly, and a read-only
  modem storage service using the downstream UIO driver.
- Keep `/dev/subsys_modem` open under OpenRC: this downstream kernel boots
  firmware on open and releases the modem on close. Mainline remoteproc
  startup controls do not apply to this device tree.
- Include 339 stock vendor/APNHLOS/CP firmware files, rather than a single touchscreen
  blob. Preserve device-specific calibration partitions on the tablet.
- Use Xfce, OpenRC and software-rendered DRM modesetting for display bring-up.
  An isolated Turnip driver built for the downstream KGSL ABI provides tested
  Vulkan computation and graphics. Plasma Desktop and GNOME Desktop use the
  tested private Zink runtime for accelerated composition; Xfce retains its
  software OpenGL configuration.
- Build locally in WSL Ubuntu on its native ext4 filesystem.

## Validation boundary

Initial full installer (historical): `artifacts/postmarketOS-SM-T505-OrangeFox-bringup-r2.zip`,
about 622 MiB, packaged locally in WSL Ubuntu from the locally built kernel
and root filesystem. Its SHA256 is recorded in `artifacts/SHA256SUMS`.
ZIP CRC checks passed, and its embedded boot image and module list match the
verified files. Seven locally compiled APKs are saved under `artifacts/apks/`.
The user sideloaded the original ZIP on 2026-10-09. OrangeFox kept userdata
mounted at `/data` and `/sdcard`; the upstream chroot mount check could not
see those mounts. The installer wrote the nested MBR inside userdata, then
failed when kpartx could not claim the busy partition. It did not reach
filesystem formatting or boot flashing. Logs are saved under
`evidence/sideload-failure/`.
The boot backup's SHA256 also matches the supplied stock boot image exactly.

Revision 2 checks userdata mounts outside the chroot by device number,
unmounts aliases and child mounts, and refuses a busy target. Inside the
chroot, `/proc/1/mountinfo` retains OrangeFox's mount view. The replacement
builds and validates the nested MBR on a sparse regular file, clears old
Android superblocks in the reserved 1 MiB gap, writes only inside userdata,
verifies the MBR readback and block mapping sizes, and stops before formatting
if any setup step fails. It avoids a global partition-table reread.

Local WSL tests passed for unmount ordering, busy-target rejection, setup
error handling, nested mappings, ext2/ext4 formatting and mounting, and
preservation of a simulated outer GPT. The tablet's ARM64 recovery tools
also validated the full-size sparse table and created both mappings on a
disposable loop image in RAM. Those recovery tests did not modify physical
partitions. Ten read-only partition backups, including boot, OrangeFox, EFS,
modem calibration and persist, are saved in
`artifacts/backups/20261009-214946/` with sizes and SHA256 hashes.

Local checks have passed for 35 ARM64 driver modules, 9 enabled OpenRC
services, 10 stock PD manifests, and 15 early touchscreen firmware files.
The generated v2 boot image is 29,253,648 bytes, fits the measured 96 MiB
boot partition, contains 12 valid DTBs, and shares the stock SoC identifiers.
Embedded configuration checks confirm USB RNDIS/ECM, Qualcomm UART Bluetooth,
QRTR/SMD, UIO modem memory and the root filesystem drivers. The modem holder's
startup, regular-file rejection and graceful termination were exercised with
`/dev/null` in the ARM64 build root, without using a tablet subsystem.

The historical Xfce installation used kernel #9 and device release 21, applied through
boot-preserving incremental updates. The historical full installer above does
not contain these later fixes. A refreshed r4 clean-install candidate now
contains kernel #9, device r22, camera r2, GPS r3, audio r3 and rotation/sensor integration.
Its 37 embedded modules and actual APK versions pass local verification;
the boot image is byte-identical to the tested tablet's boot. The refreshed
rootfs has not been flashed or boot-tested as a whole; see CURRENT-BUILD.md.
The current tablet is in desktop QC on GNOME r12 with kernel #10 and device r23.
After its live GTK OpenGL session correction and reboot, the user confirms
Settings, Files, Calculator and Terminal open. Rotation and the custom Camera
also pass. See UI-QC.md for each clean image's results and
KERNEL-COMPATIBILITY.md for the API backports and pending kernel #11 candidate.
The latest WLAN startup and device APKs were
built locally in WSL and verified on one normal reboot; the kernel boot image
remained unchanged during the WLAN update. The subsequent Bluetooth update
adds BNEP/HIDP modules and supervised stock-firmware initialization. Its boot
image was installed through OrangeFox and readback verified; one normal boot
confirms automatic Bluetooth, desktop/touch/mouse, and Wi-Fi reconnection.
Bluetooth PAN DHCP, directly bound DNS, and certificate-validated HTTPS pass
through the user-paired laptop. See BLUETOOTH-REPORT.md.

A successful build does **not** establish a fully working port. Staged device
tests now establish the partial results below.

| Feature | Source/firmware present | postmarketOS runtime status |
|---|---|---|
| Boot, eMMC, microSD, USB | Kernel drivers retained | Automatic normal boot reaches the graphical login and Xfce; USB SSH starts automatically through #9; hot insertion of a 58.2 GiB SDXC card is detected, FAT32 read-only mount and 1 MiB read pass; card writes and desktop automount unverified; see SD-CARD-REPORT.md |
| Display and touch | Vendor SDE/Himax and stock touch firmware | Kernel #8 restores SSPP plane state on wake; physical login and three-second DPMS wake verified; three additional cycles completed, Xfce and touch confirmed afterward; suspend and long idle unverified |
| Wi-Fi | qcacld/ICNSS and stock WLAN firmware/config | Device r13 initializes matching stock board data automatically; saved network reconnects before login after one reboot; DHCP, DNS, Wi-Fi-bound IP/hostname pings and certificate-validated HTTPS pass; both-band scanning works; stock MAC provisioning, suspend, and sustained throughput unverified |
| LTE/mobile data | QRTR, IPA/RMNET, signed modem firmware | Automatic IPA creates rmnet_ipa0 and ModemManager exposes the Qualcomm modem; device r11 orders D-Bus providers before clients, with supervised Polkit and ModemManager verified after one normal reboot; mobile data is user-confirmed working on 2026-10-13 after inserting a phone SIM; earlier limited/searching service used an experimental SIM with no data plan; calls, SMS and data reconnection after reboot remain unverified; see LTE-REPORT.md |
| Speakers, microphone, headset | Vendor audio modules, DSP firmware, stock FS1801 preset, and device-specific UCM | Audio r3 fixes rough playback startup with interrupt scheduling; tones, incoming Bluetooth audio and volume keys pass. UCM r4 adds the physical mono 48 kHz microphone; direct/desktop acoustic tests and a native video with an audio track pass. The user confirms clear voice recording/playback before and after reboot. Headset/call routing, extended quality and system suspend remain unverified; see AUDIO-REPORT.md |
| Bluetooth | Stock WCN3988 firmware, vendor power, GENI UART/H4, BNEP/HIDP/UHID | Kernel #9/device r15 initialize the radio automatically with the stock address; paired BLE RAPOO mouse reconnects after reboot and the user confirms pointer/clicks; laptop PAN DHCP and Bluetooth-bound DNS/HTTPS pass; incoming audio is audible and smooth with audio r3; classic HIDP socket tests pass, but physical classic HID, Bluetooth transmission/headsets, power saving and suspend remain unverified |
| GPU acceleration | Downstream KGSL and stock GPU firmware | Turnip KGSL verifies 4096 compute results as root and tablet; physical-device Vulkan 1.0.354; private Mesa 26.0.8-r3 Zink verifies shader readback, GBM sharing and native Wayland presentation; Plasma KWin and GNOME Shell use Adreno after reboot, with physical wake, rotation, input and custom-camera checks; GNOME GTK apps pass after selecting OpenGL; native GTK Vulkan, a Firefox GPU fault, Plasma rotation artifacts above 100% scaling and long stability remain unresolved; Xfce retains software GL; see GPU-REPORT.md |
| Cameras | Matching stock CamX HAL runs in isolated Bionic userspace | Rear HI846 and front GC5035 pass 640×480 preview and full-size capture at 3264×2448 / 2592×1944 in the custom app. The live GNOME PipeWire adapter exposes both standard 640×480/10 fps sources and starts automatically after reboot; the user passes standard Camera previews, orientation, colors, saving and clear video voice recording. Snapshot r1 fixes the reproduced shutter-player/photo crash sequence; eight front JPEGs and repeated rear photos with sound pass, and QR scanning is user-confirmed. Long recording stability, generic V4L2 access and suspend remain unverified; see CAMERA-REPORT.md |
| Rotation | Downstream ADSP/SSC, Bosch bmi26x and stock factory registry | Device r16 starts read-only private registry serving and SensorProxy automatically; Xfce rotation/touch work in all four positions, startup passes one normal reboot, and patched lock-screen resizing/unlocking is user-confirmed; rotation lock control passes |
| GPS and other sensors | Downstream QMI LOC v2 and sensor interfaces retained | Standalone and GeoClue fixes pass, including after reboot. ModemManager r5 repairs assistance discovery/injection ordering and passes 38 upstream tests. The new client-triggered service loads orbit assistance automatically, reuses its private cache and starts after reboot without enabling GPS itself. A window test acquired a fix in 6.12 seconds; this is not a controlled cold-start or Maps latency guarantee. App delivery latency, suspend, power consumption and remaining sensors need checks; see GPS-REPORT.md |
| Battery, charging, suspend | Stock SMB5/QG/CW2017 vendor drivers retained | Percentage and USB power reporting checked; 500 mA computer input gives about 35–38 mA net charge with the screen on and 472 mA off; growing desktop charge estimates reproduced from net power; JEITA/step charging enabled and temperature-protection bypass disabled; wall charging, full-charge termination, runtime, thermal cutoff and suspend unverified; see BATTERY-REPORT.md |

The user subsequently completed installation and reported a boot loop.
Recovery history confirms installer success, and the installed boot matches
the built image. The user's clean screen transcription confirms filesystem
checks, resize completion, root and boot mounts, and the switch_root handoff.
The next message deliberately disables console output. Initial recovery
records could not establish the reset cause because
the compressed crash record and parts of pmsg contain damaged bytes. The
root filesystem could be mounted read-only without journal replay, but it
has no persistent runtime boot/syslog output. Saved evidence and its limits
are documented in `evidence/bootloop-20261009/BOOTLOOP-REPORT.md`.

The WSL-built boot-only diagnostic update keeps the kernel and DTBs unchanged,
adds a tested static ARM64 /dev/kmsg collector, enables OpenRC file logging,
and keeps console output active. It preserves the Linux filesystem and recovery.
Logs are saved under /var/log/gta4l and /var/log/rc.log. See DIAGNOSTICS.md.
Next verification is log capture during a diagnostic boot, followed by correction
of the identified failure and hardware tests.
Do not describe this port as fully working until those checks pass.

On 2026-10-10 a staged boot and an isolated syscall trace captured the primary
panic: bluetoothd's first HCI socket causes a BUG in bt_sock_create. The vendor
HCI constructor is commented out but returns success, leaving sock->sk NULL.
A patch restores the matching Linux stable 4.19.300 HCI implementation and
has built successfully in WSL. Its boot image was installed through OrangeFox
and readback verified. On kernel #4-postmarketOS, ten HCI sockets were created
and closed successfully; default startup with Bluetooth enabled stays running.
This verifies the original panic fix, not controller or radio functionality. Separately,
Bubblewrap was rebuilt with its Linux 4.19 compatibility path and installed.
The subsequent Xorg modesetting package guards an uninitialized output-property
atoms pointer. Kernel #5 (4.19.300-r4) supplies the cached refresh rate required
by the vendor DSI validator. Together these fixes produce a physical graphical
login and Xfce desktop. The user confirmed correct touch after removing the extra
rotation; the identity calibration is packaged in device release 7.
The boot-only normal-startup image removes the diagnostic shell pause while
preserving the verified kernel, ramdisk and DTBs. Its installed readback matches
the build; the user confirmed an automatic graphical login, and SSH logs show
the Xfce session running. The desktop still uses software rendering. An isolated
KGSL Vulkan driver built in WSL has passed a GPU computation and readback test
as root and the normal tablet user. A 300-frame Vulkan graphics test also
passes through the X11 copy presentation path. See GPU-REPORT.md. The panel
later remained black after idle despite a live Xfce session and working SSH;
kernel #6 fixes a positive backlight callback return and parses the optional
GPIO previously left as GPIO 0. Its normal startup, full brightness write and
HCI regression pass, but the panel still fails to resume. Logs show the
asynchronous touchscreen firmware reload resetting the shared TDDI chip after
LCD setup. Kernel #7 orders that reload before LCD commands but still fails
physical wake. Kernel #8 also restores unchanged SSPP plane state during the
CRTC enable transition; physical DPMS wake and subsequent desktop/touch pass.
See DISPLAY-RESUME-REPORT.md.
Wi-Fi initialization now reaches firmware readiness and creates the interfaces.
Both-band scans work. A reproduced Polkit process-identity error explained a
desktop authorization failure; the service identity and authentication agent
have been repaired. Device r13 starts WLAN automatically and reconnects the
saved network before login; DHCP, DNS, pings, and certificate-validated HTTPS
pass after reboot. See WIFI-REPORT.md.
The detailed evidence is in
`evidence/diagnostic-boot-20261009/HCI-CRASH-REPORT.md`.
