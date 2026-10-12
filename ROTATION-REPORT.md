# SM-T505 automatic rotation

Rotation uses the downstream ADSP sensor service through QRTR, libssc and
iio-sensor-proxy. The tablet reports a Bosch bmi26x accelerometer. Its stock
firmware mount matrix is empty; the device udev rule supplies the measured
180-degree correction. Upright portrait has approximately +9.8 m/s² on the
uncorrected Y axis and reports `normal` after correction.

The `rotation-gta4l` package starts a helper in the logged-in Xfce session.
It claims SensorProxy under the normal active-session Polkit policy, rotates
DSI-1, and applies the corresponding matrix to the Himax pointer. It leaves
the separate Himax keyboard device alone. A flat tablet retains its previous
orientation. Rotation lock and screen blanking release the sensor claim.

| Sensor orientation | Xrandr rotation | Touch transform relative to the working portrait calibration |
|---|---|---|
| normal | inverted | identity |
| bottom-up | normal | 180 degrees |
| left-up | right | 90 degrees |
| right-up | left | 270 degrees |

The user confirmed correct rotation direction and touch in all four positions.
Xorg and Xfce change desktop/workarea dimensions between 1200×2000 and
2000×1200. Testing also exposed a separate Xfce lock-screen bug: its background,
XEmbed plug and embedded keyboard retained their previous size. The local
`xfce4-screensaver` 4.20.2-r1 patch updates those allocations on monitor geometry
changes, while retaining the authentication dialog and existing lock state.
After a normal reboot, the user confirmed correct desktop/keyboard layout and
touch. A separate locked-screen rotation test confirms resizing without clipped
keys or black borders, followed by successful unlocking. The rotation lock
control also releases/reclaims the accelerometer and returns to automatic mode.

The sensor file server is built for this kernel's 64-bit downstream FastRPC
ABI. It attaches the sensor protection domain through the privileged ADSP
node, which remains accessible only to root. Three upstream HexagonRPC tests
and an ABI comparison against the actual kernel header pass in the WSL build.
Libssc's seven service tests skip in WSL; actual tablet measurements provide
the hardware evidence instead.

Stock sensor DSP libraries and configuration are packaged separately from
per-device calibration. The startup helper reads the named `persist` partition
using debugfs without write access, copies the factory registry into a private
root-owned cache, and serves it read-only. It never mounts or writes the factory
partition. A fresh boot verifies automatic cached-registry startup and rotation
without the original probe server. The first attach attempt occurs before the
DSP channel is ready; OpenRC retries successfully. Broader startup timing and
suspend testing remain open.

User commands:

```sh
gta4l-rotate --status
gta4l-rotate --toggle
gta4l-rotate --portrait  # lock upright portrait
gta4l-rotate --unlock   # resume automatic rotation
```

There is also a **Toggle rotation lock** entry in the applications menu.
The initial graphical login keeps the existing portrait orientation; automatic
rotation starts after login. Suspend and sensor power consumption remain
unverified. GPS, compass and camera functionality are separate work.

All new APKs are built locally in WSL Ubuntu. Package hashes and runtime
verification flags are recorded in `artifacts/rotation-verification.json`.
Private raw measurements, layout captures and startup logs remain under
`evidence/diagnostic-boot-20261009/` and are excluded from Git.
