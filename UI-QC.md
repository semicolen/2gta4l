# SM-T505 desktop quality checks

Test each clean image on the tablet, one at a time, with the user verifying
visible output and interaction. The order is Xfce, Plasma Mobile, Plasma Desktop,
GNOME Mobile, GNOME Desktop, and Sxmo/Sway. After all six tests, the user will
choose which tested UI to leave installed. During the Plasma Mobile test, the
user narrowed the remaining QC to Plasma Desktop and GNOME Desktop because the
mobile layout and performance were a poor fit for this tablet. On 2026-10-15,
the user requested GNOME Desktop followed by GNOME Mobile. Sxmo remains outside
the current QC scope.

Before the first clean installation, preserve a complete offline raw userdata
backup and the working boot image. Private backups and recovery/runtime logs
stay in the Git-ignored `artifacts/` and `evidence/` directories. Each installation
formats userdata; personal settings and pairings do not transfer between images.

| UI | Clean install | Login and input | Rotation and wake | Network and audio | Cameras and GPS |
| --- | --- | --- | --- | --- | --- |
| Xfce | Passed | Desktop, touch and keyboard passed | Earlier results; not repeated | Earlier results; not repeated | Earlier results; not repeated |
| Plasma Mobile | Passed, with runtime fixes | Touch and keyboard passed after calibration; desktop usable but janky | Rotation not working; wake not checked | Wi-Fi and certificate-validated HTTPS passed after provider fix; audio not repeated | Not repeated |
| Plasma Desktop | r10 clean installer completed; boot readback and unchanged recovery passed; USB SSH returned | Fresh desktop opens with Adreno rendering; earlier login, touch and keyboard checks passed | Fresh rotation animation clean at 100%; lines and incorrect colors at larger scales; unresolved and deferred by user | Earlier Wi-Fi and audio passed, including certificate-validated HTTPS | Both camera colors/orientations, photo saving and preview restart passed with signed r5 on accelerated desktop; GPS not repeated |
| GNOME Mobile | r14 built and locally verified; tablet installation pending | Untested | Untested | Untested | Untested |
| GNOME Desktop | r13 OrangeFox install, matching boot readback, unchanged recovery and normal boot passed; r14 built and locally verified, fresh-install QC pending | Restored account, desktop/apps, touch and keyboard pass; actual Adreno compositor verified | Rotation/input and five-second display off/on pass | Speakers and microphone recording/playback pass, including microphone after reboot; earlier wlan0 ping, DNS and certificate-validated HTTPS pass | Custom and standard Camera previews/photos pass; live Snapshot r1 repeated photos with sound and QR scanning pass; automatic GPS assistance and receiver fix pass, Maps delivery latency pending |
| Sxmo/Sway | Skipped by user | Untested | Untested | Untested | Untested |

Live GNOME follow-up on 17 October adds standard PipeWire rear/front camera
discovery. The user passed both standard-app previews, colors, orientation and
photo saving, then reported intermittent photo crashes and silent video audio.
Audio UCM r4 now exposes a physical microphone and passes direct capture,
desktop capture and saved-video audio measurements. The user confirms clear
recorded speech on playback. The photo crash reproduces after replacing the
shutter-sound player. The signed Snapshot r1 patch is now installed: eight
front JPEGs with sound and repeated rear photos pass, and the user confirms
QR scanning. Automatic GPS orbit download/injection also passes and a
window test acquired a fix in 6.12 seconds; Maps delivery latency remains open.
These live additions are not part of the historical r13 installer.

For each UI, check login, desktop sizing, touch, on-screen keyboard, rotation,
lock/unlock and display wake. Then check Wi-Fi connection and internet access,
mobile data with an active SIM, Bluetooth input/audio, speaker startup and volume
keys. Use the port's Camera app to check both previews, colors, photo saving and
orientation. Check GPS through GeoClue, including consent and a satellite fix
when the tablet has a clear view of the sky. Record unavailable test equipment
and unverified features explicitly.

Capture installer completion and boot readback before the first boot. Assembly
checks, a successful boot, and a user-confirmed hardware test are separate
results; none establishes that every feature works across all desktops.

On 2026-10-14, Plasma Desktop's actual KWin compositor reports Zink/Turnip
Adreno 610, OpenGL ES 3.2 Mesa 26.0.8 after a normal reboot. The user confirms
visible acceleration, smooth rotation transitions, wake and input, and all
camera regressions. The r10 installer recipe includes the tested private
runtime, GPU session environment and software fallback. Other profiles retain
their previous rendering configurations; GNOME Desktop QC remains pending.

The accelerated Plasma r10 clean installation completed through OrangeFox on
2026-10-14. Its boot readback matches the tested kernel #9 image and recovery
is unchanged. Installed port package versions match the build receipt, fresh
SSH host keys were pinned through recovery, and USB SSH returned on first boot.
The fresh user's home contains the GPU environment from `/etc/skel`. KWin's
active renderer again reports Zink/Turnip Adreno 610. The user reports lines and
incorrect colors during rotation animations at larger display scales, while
100% scaling is clean. No new GPU fault appears in the collected kernel log.
The offscreen texture-size regression passes RGBA8 and RGBA16F at panel-sized
and odd dimensions; it does not establish the cause of the compositor artifact.
The user chose to defer that issue and proceed with GNOME QC on 2026-10-15.
Plasma settings were saved privately before its clean installation.

GNOME Desktop r10 was installed on 2026-10-15, with its port packages verified
and fresh SSH host keys pinned through recovery. Initial login-screen touch
was misaligned. A GNOME-only rule overrides the device's Xfce identity matrix
with the physical 180-degree calibration already required by KWin. The new
udev property persists after a clean reboot; GNOME r11 recipes include it for
both GDM and the user session. Physical input and rotation checks are pending.
GNOME Shell 51 starts under the OpenRC-compatible gnome-session 48, using the
current software renderer. Login is delayed: a disposable child test confirms
that the kernel accepts pidfd_open but rejects waitid(P_PIDFD) with EINVAL,
and GNOME's session log reports that same child-watch error before the desktop
eventually starts. Kernel #10 adds the missing child-wait API and remaps four
Himax gesture keys that collide with Linux mouse buttons. Mutter 51 classifies
the original mixed-capability device as a pointer rather than a touchscreen,
which prevents its tablet rotation policy from engaging. Both fixes compiled
locally in WSL; all 37 modules, the device tree and boot ramdisk are unchanged.
The boot-only OrangeFox update passed boot readback and preserved recovery.
Kernel #10 passes normal boot, pidfd status/ownership/error checks and the actual
Himax capability check. GNOME's early accelerometer claim then exposed a separate
SensorProxy startup race; the local 3.9-r4 fix passes an observer started before
the service, delivering orientation and tilt after discovery. GNOME's isolated
Vulkan computation, GLES shader/readback, display-buffer import and native
Wayland presentation tests pass. An accelerated user-session trial is prepared,
with a software greeter and fallback. After the clean reboot, the actual user
compositor maps the private Mesa 26.0.8 libraries and Turnip driver, has the
Adreno device open and has no LLVM library mapped. The user confirms rotation,
touch and keyboard, then display wake and input after a five-second off/on test.
Both custom-camera previews, colors, orientations, photo saving and preview
restart are user-confirmed. Closing the app leaves only its idle controller and
no capture helper or temporary frames; a full-resolution front PNG is verified
on disk. Wi-Fi also passes ping, DNS and certificate-validated HTTPS through
wlan0. GNOME r12 is locally assembled and has installed through OrangeFox with
matching boot readback, unchanged recovery and new SSH keys pinned directly
through recovery. The user completed the normal boot and confirmed rotation
and Camera, but ordinary GTK 4 apps failed to launch. Direct app probes under
the compositor's environment reproduced SIGBUS with native Vulkan presentation;
selecting `GSK_RENDERER=gl` keeps them running on private Zink/Turnip. The GNOME
session wrapper now sets that renderer and explicitly exports
`LIBGL_ALWAYS_SOFTWARE=0` for the accelerated session, including D-Bus-activated
apps. After reboot, the user confirms Settings, Files, Calculator and Terminal
all open normally. Evidence under `evidence/ui-qc/gnome/20261016-app-fix/`
confirms the corrected user/app environment and actual Adreno compositor.
The r13 images include this fix; the original r12 ZIP does not. Kernel #11 also
adds faccessat2 because GLib's no-follow access check otherwise returns false
for a real file. Its guarded boot-only update passes boot readback and preserves
recovery. Native permission, symlink, directory-fd, empty-path, legacy access
and unprivileged GLib checks pass, along with the ARM32 syscall dispatch and
the previous pidfd/Himax regressions. The active GNOME compositor still has
Adreno open, and the user confirms desktop, Settings, Files, rotation, touch
and keyboard. Both r13 GNOME images pass local assembly and receipt checks.
Desktop r13 installed through OrangeFox with matching boot readback, unchanged
recovery, restored requested account and new SSH keys pinned through recovery.
After leaving OrangeFox sideload mode, its first normal boot and fresh
package/session-wrapper checks pass. GLib file checks and GPU device access
pass as the restored account. Its visual login check is pending. Mobile r13 awaits its first tablet
installation. A normal restart occurred while stopping the active user
session before the recovery request completed; retrying from the fresh greeter
entered OrangeFox successfully. Its cause remains unestablished.

A new desktop account initially lacked access to KGSL/ION. The user approved
adding the same hardware groups as the default account and confirmed its
desktop and apps then open. The requested private account backup is verified
on device and host, and a disposable WSL overlay test verifies restoration,
repeat restoration and preservation of other credentials. Clean UI tests retain
the requested login with fresh home defaults; saved configuration stays in the
private backup. No credentials are included in the public images.

Xfce's fresh r5 installation passed on 2026-10-13: installer completion, matching
kernel #9 readback, unchanged OrangeFox, automatic normal boot and USB SSH. The
user confirmed the desktop, touch and on-screen keyboard. At the user's request,
the full hardware regression was omitted because Xfce was already used for the
port's earlier hardware tests.

Plasma Mobile's r5 image required three corrections: retain the existing RNDIS
USB setup by disabling `usb-signaller`, save the Himax 180-degree calibration in
KWin, and replace the ConsoleKit Polkit libraries with the elogind provider.
After a clean reboot, one active compositor remained and Wi-Fi HTTPS succeeded
with certificate verification. Restarting tinydm during diagnosis had left
multiple Plasma sessions running and caused out-of-memory process kills; a full
reboot cleared them. The user reported a usable but janky desktop and no working
automatic rotation. These corrections do not turn the original r5 ZIP into a
verified final installer; the build recipe carries them into the r6 candidates.
