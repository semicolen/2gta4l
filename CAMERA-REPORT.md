# SM-T505 camera development

The live GNOME Desktop installation now has `camera-pipewire-gta4l` 1.0-r0.
It exposes rear and front 640×480, 10 fps RGBx sources through PipeWire, using
the existing permission-controlled HAL broker. Normal application discovery,
automatic stream linking, changing live frames, orientation and hardware release
when idle pass. The user confirmed both cameras, orientation, colors and photo
saving in GNOME's standard Camera app. These additions are not in the historical
r13 installer. The custom app retains full-resolution still capture.

`snapshot` 51.0-r1 fixes the reproduced photo-crash sequence by reusing the GTK
shutter-sound player. The earlier version faults in GTK rendering after replacing
that player: two photos reproduce a SIGSEGV, while eight shutter actions survive
with sound disabled. Native Wayland/EGL selection and the per-app
`GDK_DISABLE=threads` test did not resolve it.

The patched candidate saves eight consecutive front-camera JPEGs with shutter
sound enabled and remains running. The user also confirms repeated rear photos
save without a crash and repeated shutter sounds work, and reports successful
QR-code scanning. The signed package is installed; all allocated executable code
and data match the hardware-tested candidate, Cargo audit metadata is retained,
and the installed app launches with the usual Zink driver. The upstream
`cargo test` command passes but currently contains zero unit tests; the tablet
photo checks provide the functional regression evidence. Longer stability is
still unverified.

Microphone UCM r4 separately passes an eight-second native video/audio test, and
the user confirms clear voice recording and playback before and after reboot.
The camera-source supervisor and both sources start automatically after a normal
reboot. The refreshed GNOME Desktop and Mobile r14 images are built and locally
verified; their fresh-install QC remains pending. These changes are absent from
the historical r13 installers.

During Plasma Desktop quality control, camera r5 adds native Wayland output
orientation to the GTK frontend while retaining the Xfce rotation-cache path
for X11. The frontend reads the actual `DSI-1` output transform, so it follows
display orientation rather than independently rotating from sensor data. The
mirrored front view needs the opposite landscape conversion from the rear view.
The user confirmed correct front/rear previews, photo saving and preview restart
with the tested r5 frontend. The signed package contains that byte-exact code;
the user also confirmed the camera, touch, keyboard, login and rotation after
a fresh reboot with the signed r5 package. Clean-installer checks remain in
progress in `UI-QC.md`.
On 2026-10-14, both camera previews, colors, landscape orientation, photo saving
and preview restart also pass on the accelerated Plasma Desktop. Closing Camera
leaves no capture helper or temporary frames; the idle controller stays running.

The same quality check found a misleading stop error after a completed photo.
Full-resolution PNGs were already saved, but the frontend briefly treated the
photo helper's successful exit as a failed preview. It now waits for the
photo-to-preview transition before interpreting preview exit status. These
changes keep the stock HAL, capture helper, color conversion and firmware path.

GNOME Desktop QC on 2026-10-15 confirms the custom Camera app opens and produces
images, while generic camera applications did not discover a camera at that time.
The HAL broker itself exposes a private capture protocol; the new PipeWire adapter
described above now supplies standard application discovery in the live build.
After the kernel #10, SensorProxy and Adreno GNOME session fixes, the user confirms
both moving previews, colors and orientation in portrait/landscape, photo saving
and preview restart in the custom app. Closing Camera releases the capture helper
and temporary frames. Those earlier checks predate the PipeWire adapter.

Both physical cameras capture images using the matching stock Android 12 CamX
HAL in an isolated Bionic runtime. Each camera completed 30 consecutive
640×480 YUV captures and 15 consecutive captures at its maximum advertised
YUV resolution: 3264×2448 rear and 2592×1944 front. Camera package r2 corrects
chroma order and adds full-resolution photo capture to the native GTK app.
Both full-photo IPC checks passed, including preview restart and cleanup.
Disconnecting during a photo cancels capture, flushes/closes the sensor,
releases its buffer and does not publish an incomplete image.

The native app previously passed rear/front preview, lens switching, photo
saving, all four preview orientations and fresh capture after reboot at r1.
The user subsequently found incorrect colors in preview and full-size images;
a paired comparison confirmed the swapped-chroma conversion restores real
colors. The user confirms correct colors in both native previews, full-photo
saving and preview restart at r2. Saved PNG dimensions confirm a full-size
front photo; an automated test of the exact installed GTK class also saved
a 3264×2448 rear PNG and verified preview restart. Closing the app releases
capture. Device release 21
starts the idle controller automatically after reboot.
The r2 reboot regression also passes the installed GTK app's complete preview,
full-photo save and preview restart for both cameras. A final check confirms
the controller is idle, temporary frames are absent, no capture helper or
global camera mounts remain, and the kernel boot image is unchanged.

| Camera | Actual sensor/profile | HAL ID | Sensor orientation |
|---|---|---|---|
| Rear | HI846 / `n19_hi846_back_txd` | 0 | 90° |
| Front | GC5035 / `n19_gc5035_front_qunhui` | 1 | 270° |

The HAL advertises and delivers YUV up to 3264×2448 rear and 2592×1944 front.
Live preview remains 640×480. Take photo pauses preview, captures 15 frames
with the still-capture template, saves the final full-size frame as an oriented
PNG under `Pictures/Camera`, then starts preview again. Capture currently
takes approximately 16 seconds, before PNG saving and preview startup.

The sensor identities come from successful stock HAL sensor/EEPROM probing.
The kernel exposes four sensor slots, but the HAL identifies two physical
cameras. No factory calibration or modem NV partition was written.

## Runtime and capture compatibility

The stock `camera.qcom.so` SHA256 is
`3dfa3c004119eea2e70114689ea39025a60c1349f7564977626c5b0974f378a8`.
Its camera-module structure has an extra method after `get_camera_info`;
the initialization method is at offset 304. The diagnostic uses this verified
device-specific layout and checks the matching HAL hash. Calling the generic
AOSP offset initially reached the torch method and crashed the diagnostic;
the corrected method layout passes enumeration and capture.

The small ARM64 helper is built locally in WSL Ubuntu with Clang and the
matching stock Bionic linker/libc. Its camera3 and graphics buffer layouts
are checked against pinned Android 12 AOSP headers. Stock vendor, Bionic and
VNDK libraries are extracted locally from the supplied firmware; they are
used as supplied. Missing dynamically loaded CHI use-case and OPE striping
libraries were added to the runtime after tracing actual failures.

Stock gralloc1 allocates a 640×480 flexible-YUV buffer with a 1024-byte row
stride. CPU readback uses its returned plane addresses and increments,
including interleaved chroma. This Qualcomm implementation reports chroma
subsampling on its luma plane as well; the narrowly scoped readback adjustment
keeps luma at full resolution. The matched isolated CamX runtime writes
interleaved chroma in the opposite order from the allocator's Cb/Cr labels.
Paired readback of the same buffer, with only chroma order changed, showed
correct colors with the swapped conversion. The adjustment requires the exact
observed layout: Cb address one byte after Cr, two-byte chroma increments and
equal chroma row strides. An unexpected layout fails validation. This is
scoped to the matching stock HAL/runtime and is not a general YUV rule.
Returned synchronization fences are passed
to the next request or consumed by the graphics CPU-lock operation. Each
sequence has one request in flight, with bounded waits and explicit cleanup.

The first GPU-backed capture crashed because KGSL could not load
`a630_sqe.fw` from the camera process's isolated filesystem root. Kernel logs
and syscall tracing confirmed the firmware failure even though the GPU device
node existed. Exposing the installed matching firmware read-only inside the
private mount namespace fixed GPU initialization and image delivery. Device,
proc and sys mounts are temporary; proc, sys and firmware are read-only.

## Evidence and current limits

`camera-gta4l-1.0-r2` and its OpenRC subpackage are built locally in WSL,
including compilation of the helper from source within the APK build. The
native GTK app offers rear/front preview and stores photos under
`Pictures/Camera`. Its root controller accepts only fixed commands over a
local socket restricted to the video group. It starts the camera only when
requested and stops it on client disconnect or inactivity. Invalid commands
and non-video access were rejected in hardware-side checks. Captures use a
private mount namespace; cleanup left no global mounts and removed the shared
live frame. Photo capture has a 35-second process timeout and a further
five-second kill deadline. Video-group clients can read completed full-size
frames, but cannot write that shared directory. PNG files are saved by the
desktop user with mode 0600. Full-size rear and front PNGs are verified on disk.
Ten photos were present at final validation. Earlier 640×480 files are preserved.

`artifacts/camera-verification.json` records frame counts, image hashes,
brightness statistics and verification flags. Private captured images remain
on the tablet. The main local evidence is:

- `device-r20-camera-rear-sequence.raw`: all 30 rear frames succeeded;
  final luma range 8–239, mean 145.
- `device-r20-camera-front-sequence.raw`: all 30 front frames succeeded;
  final luma range 13–241, mean 115.
- `device-r20-camera-review-state.raw`: two complete 921,615-byte PPM images,
  running desktop review window and unchanged boot ID.
- `device-r20-camera-gpu-firmware-diagnose.raw`: the firmware lookup failure
  behind the earlier GPU plugin crash.
- `device-r21-camera-r2-rear-photo-check.raw` and front equivalent: 15
  full-size frames per camera, preview restart and disconnect cleanup.
- `device-r21-camera-r2-photo-cancel-check.raw`: mid-capture disconnect
  releases the sensor and buffer without leaving a photo.
- `device-r21-camera-app-after-reboot-closed.raw`: r1 fresh reboot test,
  both previews and saving user-confirmed, six saved PNGs, clean sensor close.
- `device-r21-camera-r2-native-rear-photo-regression.raw`: the installed GTK
  app's preview, shutter signal, full-size PNG save and preview restart pass.
- `device-r21-camera-app-r2-closed.raw`: both full-size saved PNG dimensions,
  mode 0600 and clean hardware release.
- `device-r21-camera-r2-native-rear-after-reboot.raw` and front equivalent:
  both native full-photo paths pass after the fresh reboot.
- `device-r21-camera-r2-final-state.raw`: exact APK versions, ten saved PNGs,
  idle cleanup and unchanged boot-image SHA256.

Recording, autofocus controls, native V4L2/PipeWire application access, suspend/resume,
long-duration stability and power consumption remain unverified. Optional
stock Android service warnings are still present; successful captures do not
establish that all stock processing features work. The local OrangeFox r4
clean-install candidate includes camera r2 and the tested boot; its refreshed
rootfs remains unflashed. See CURRENT-BUILD.md.
