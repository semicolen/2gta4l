# SM-T505 GPS verification

GNOME Desktop r13 initially exposed an assistance gap: ModemManager r3 reported
no assistance support although direct QMI returned three HTTPS XTRA servers.
ModemManager r5 fixes response/indication ordering for both discovery and
chunked injection; all 38 upstream tests pass. The tablet now reports assistance
support and accepts orbit data, including through the existing XTRA fallback.

The installed `gps-assistance-gta4l` service watches actual client GPS requests.
It never enables GPS itself. It downloads only the modem-advertised XTRA file
over verified HTTPS, caches it privately, and injects it while GPS is requested.
It preserves standalone satellite positioning and the client-controlled source
mask. Automatic download and subsequent cache reuse both pass; the modem accepted
cached data in 0.24 seconds and reports 168 hours of orbit validity.

Coordinate-free window tests observed a first valid fix after 39.46 seconds
before assistance, 3.06 seconds after manual injection, and 6.12 seconds with
the automatic service. These are reception samples with warm-start effects,
not controlled cold-start comparisons or guaranteed Maps timings. Actual
GeoClue/Maps delivery latency still needs its final check. The assistance service
starts automatically after a normal reboot. No assistance cache, modem NV or
factory calibration was erased.

Device release 20 passes satellite reception and desktop location requests,
including after a normal reboot. At an open window, the post-reboot desktop
test received a valid GPS position: GGA fix quality 1, ten satellites used,
HDOP 0.6 and RMC status A. Closing the desktop test client disabled GPS
gathering. Coordinates and full NMEA data remain in private device logs;
the local verification artifact records validity and satellite counts.

## Request-time modem preparation

The downstream modem exposes QMI LOC v2 over QRTR. Original GPS starts failed
with QMI error 46 (`GeneralError`). A protocol trace showed an engine-lock
response with an eight-byte field that this libqmi version does not decode.
Setting the lock to `none` changed that field to zero and allowed GPS to start.
The extended mask's exact semantics have not been inferred.

ModemManager sets a lock during its capability initialization, so a startup-only
unlock was insufficient. The final patch prepares the engine immediately before
a requested LOC session. It is selected only by the device-package marker,
the `qcom-soc` plugin and the exact QRTR node 0 client. It uses the existing
QMI client and waits for both the successful response and completion indication,
with a bounded timeout. The original PDS selection and subsequent LOC start
and event registration remain intact. Other modem paths keep their original
behavior. The normal location-client lifecycle controls gathering.

An earlier subprocess implementation encountered a downstream kernel/GLib
pidfd `waitid` compatibility failure despite the helper completing successfully.
The direct QMI implementation avoids that dependency. A patch-generator scope
error in release 19 was corrected before the verified release 20; the generator
now checks preservation of the original client-selection branches.

## Local builds and hardware checks

All port package builds ran locally in WSL Ubuntu. The installed GPS stack is
`gps-gta4l 1.0-r3`, `modemmanager 1.25.95_git20261005-r3` and locally built
`geoclue 2.8.2-r0`, with device package `1-r20`. ModemManager's 38 upstream
tests passed with zero failures. GeoClue's Meson build defines no tests.
The incremental install verified package hashes and preserved kernel #9's
boot image. The historical full OrangeFox installer has not been rebuilt
with these updates.

The regression checks establish:

- A desktop request clears a deliberately imposed engine lock and receives
  a valid fix using ten satellites, HDOP 0.5, before reboot.
- After a fresh boot, the engine starts idle with its initialization lock.
  A normal desktop request clears it automatically and receives the valid
  ten-satellite fix described above.
- GeoClue delivers latitude and longitude to the normal tablet user in both
  tests. Closing its test client disables GPS gathering in both tests.
- A separate fresh-boot ModemManager request produced valid raw coordinates
  and NMEA using eight satellites, HDOP 0.5.

The post-login test requires the desktop consent agent to be registered.
A preliminary test at the login screen timed out waiting for that agent;
the logged-in regression passed. An explicit permission-agent test also
displayed a real prompt that the user accepted. Native unsandboxed applications
are treated as system applications by this GeoClue version and may bypass that
prompt. No authorization policy was weakened for this port.

The device configuration enables modem GPS and disables network, Wi-Fi, IP,
static, network-NMEA and unverified compass sources. Tests use standalone GPS.
No calibration or modem storage partitions are written by this preparation
code. GeoClue's accuracy value is an upstream HDOP conversion; zero metres
reported by the test client is not a measured accuracy guarantee.

Broader reception, assisted GPS, suspend and power consumption remain unverified.
Package hashes, boot ID and coordinate-free evidence are recorded in
`artifacts/gps-verification.json`. Cameras are the next development step.
