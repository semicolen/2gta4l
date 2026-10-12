# SM-T505 display resume investigation

Kernel #5 reliably reached a physical graphical login and Xfce, but the
panel stayed black after idle. Xorg, the framebuffer and USB SSH stayed
available. Forcing DPMS on, restoring brightness and unblanking fb0 did
not restore a visible screen.

Kernel #6 (`linux-samsung-gta4l-4.19.300-r5`) corrects the DCS backlight
success return and parses the existing panel VCC GPIO. It was built in
WSL Ubuntu, installed through OrangeFox and verified by boot readback.
The ramdisk, DTB and all 35 driver modules are unchanged. The user confirmed
the graphical login after an automatic boot; SSH also started automatically.
Ten raw HCI sockets passed the previous panic regression. A direct brightness
write returns all four bytes for `131\n` and three for `131`.

A three-second DPMS off/on cycle still produced a black screen on #6.
The logs identify a race in the shared Himax touch/display chip:

| Kernel uptime | Event |
|---|---|
| 123.149637 s | LCD `dsi_panel_power_on` finishes |
| 123.229838 s | Asynchronous touch resume resets the shared chip |
| 123.261269 s | Normal DRM unblank notification |
| 123.338939 s | Touch firmware reload finishes |

The vendor panel emits a special notification with ID 29 after its GPIO
reset and before DSI on commands. The touch driver currently handles this
by queueing work. Kernel #7 was built in WSL and installed through OrangeFox
with verified readback and unchanged ramdisk, DTB and modules. Its change handles
that pre-LCD notification synchronously, finishing the touch firmware
reload before the panel initialization commands. Notifications for other
connector IDs retain the existing workqueue behavior.

Kernel #7 automatically reaches a physical graphical login and starts SSH,
the ADSP holder and ModemManager. The HCI socket regression and root/user
Adreno compute tests pass. Its runtime logs confirm the firmware reload
finishes before LCD initialization, but the user confirmed that a three-second
DPMS cycle still leaves the panel black. This ordering change is insufficient.

Restarting LightDM restores the physical screen. A subsequent full modeset
using `xrandr --output DSI-1 --off`, then `--auto --rotate inverted`, also
restores the login screen without restarting Xorg. A bounded DRM log captures
both paths: DPMS wake retains plane 44's framebuffer and rectangles and skips
SSPP property programming; the working full modeset programs format, rectangles,
QoS and translation state. The CRTC disable path unregisters its power callback
before power-down, bypassing the existing POST_DISABLE revalidation hook.

Kernel #8 (`linux-samsung-gta4l-4.19.300-r7`) reuses that full revalidation
when the CRTC's active state changes. It was built locally in WSL Ubuntu,
installed through OrangeFox and verified by boot readback. Its ramdisk, DTB
and all 35 modules remain byte-identical to #7.

The user confirmed automatic graphical login and a successful three-second
DPMS off/on cycle without a forced modeset or service restart. The captured
log now shows full plane programming on wake. Three additional cycles with
1-, 5- and 10-second off intervals completed; the user confirmed Xfce login and
correct touch after those cycles. HCI sockets and root/user GPU compute pass on #8.
Automatic DPMS is enabled during these tests.

Evidence is in `evidence/diagnostic-boot-20261009/`:

- `backlight-normal-boot-state.raw`: kernel #6 and automatic services.
- `backlight-resume-test.raw`: successful writes and DPMS cycle.
- `backlight-hci-regression.raw`: ten successful HCI sockets.
- `panel-resume-state.raw`: actual bootloader-applied panel GPIO properties.
- `resume-log-only.raw`: touch firmware/reset timing.
- `backlight-fix-readback.json`: verified OrangeFox boot write.
- `touch-resume-fix-readback.json`: verified kernel #7 boot write.
- `touch-resume-ordered-logs.raw`: synchronous firmware reload ordering.
- `touch-resume-dpms-test.raw`: DPMS test whose physical result was black.
- `touch-resume-greeter-restart.raw`: successful greeter restart; user saw login.
- `dpms-modeset-compare.raw`: DPMS versus full modeset, user saw restored login.
- `kernel7-gpu-compute-root.raw` and `kernel7-gpu-compute-user.raw`: GPU regression.
- `plane-resume-fix-readback.json`: verified kernel #8 boot write.
- `plane-resume-dpms-test.raw`: full plane restoration; user saw successful wake.
- `plane-resume-repeat-wake.raw`: three additional DPMS cycles completed.
- `plane-resume-hci-regression.raw`: HCI panic regression on #8.
- `kernel8-gpu-compute-root.raw` and `kernel8-gpu-compute-user.raw`: GPU regression.
- `kernel8-vkcube-visible-start.raw`: normal-user Turnip cube; user saw it rotate.

The first physical DPMS wake now passes. Suspend, battery drain and long idle
behavior still need separate device validation.
