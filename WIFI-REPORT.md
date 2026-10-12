# SM-T505 downstream Wi-Fi bring-up

## Observed firmware startup

Kernel #8, device release 12, and matching T505XXS8CXG1 firmware expose the
WLFW QRTR service after normal boot. Its service number is **0x45 (decimal
69)**. A capability query identifies chip ID `0x150`, family `0x4002`, SoC
`0x40670000`, and firmware build
`WLAN.HL.3.2.4-00952-QCAHLSWMTPLZ-1.598846.2`.

The stock firmware server previously rejected all three observed
`wlanmdsp.mbn` paths because upstream TQFTP 1.2 requires
`/sys/class/remoteproc`, which this downstream PIL kernel does not expose.
The local `tqftpserv-gta4l` package supplies an explicit, read-only firmware
root before that remoteproc lookup. An ARM64 translation test in the WSL
build verifies the three request paths, read-only access, and rejection of
missing or escaping paths. The normal-boot WLFW endpoint subsequently
appeared. A complete new TFTP transfer of `wlanmdsp.mbn` was **not captured**;
the evidence does not establish which firmware-loading path supplied it.

A locally built WLFW initializer registered as an anonymous userspace
client, queried capabilities, and sent the matching stock
`wlan/qca_cld/bdwlan.bin` in five segments. All responses succeeded. The
26,328-byte file has SHA256
`a18a7fce954ca5b4e7758a4853844d1bdc48e9dbec793c54356e4667c44834e8`.
The initializer reported an empty Linux calibration-cache inventory and
received `FW_READY`. It did not fabricate calibration or write NV partitions.
The kernel also reported WLAN firmware ready.

Writing `ON` to the downstream `/dev/wlan` control then created `wlan0`,
`swlan0`, `p2p0`, and `wifi-aware0`. NetworkManager scans show nearby
access points on both 2.4 GHz and 5 GHz. The user confirms networks are
visible. Scanning alone does not establish authenticated connectivity.

## Connection and authorization

The user's first connection attempt failed. The subsequent capture showed
no saved Wi-Fi profile and no association attempt in the recent kernel log.
The normal tablet user received `unknown` for NetworkManager permissions;
`pkcheck` reproduced `org.freedesktop.PolicyKit1.Error.Failed: Process not
found`. The desktop `xfce-polkit` agent had exited.

A syscall trace established the immediate cause: Polkit successfully opened
a pidfd but received `EACCES` reading `/proc/self/fdinfo/<fd>`. Its privilege
drop had left that proc directory owned by root. Starting Polkit directly
under the existing `polkitd:polkitd` service identity, with a correctly owned
log file, restored its self-access. User permission queries now return
normal `yes`, `auth`, or `no` decisions, and `pkcheck` reaches the expected
authentication requirement. The restarted Xfce agent remains running.
Authorization policies have not been relaxed.

The user connected successfully after the repair and keyboard restart. The
tablet obtained an IPv4 lease, default route, and DNS server through `wlan0`.
Three pings each to `1.1.1.1` and `postmarketos.org` returned with zero packet
loss. A Python HTTPS probe bound the socket to `wlan0`, verified the server
certificate, negotiated TLS 1.3, and received a valid HTTP redirect. Chrony
also synchronized the tablet clock automatically after connectivity returned.

## Reproducibility and remaining work

The `wlfw-gta4l` package and device release 13 add bounded automatic
initialization before NetworkManager and wpa_supplicant, plus the Polkit
service configuration. The initializer includes MSA readiness and matching
chip/board checks. Both packages built locally in WSL Ubuntu and were installed
with the existing kernel #8 boot image verified unchanged. One normal reboot
then sent all five board-data segments automatically, received FW_READY,
created the interfaces, and reconnected the saved network before desktop login.
Both ping tests and certificate-validated HTTPS passed again after reboot.
Polkit and ModemManager both had OpenRC supervisor parents. The user confirmed
Xfce, correct touch, and the on-screen keyboard after reboot. Package hashes
and bounded runtime results are recorded in
`artifacts/wlan-startup-r13-verification.json` and `artifacts/SHA256SUMS`.

The currently reported permanent WLAN MAC is a driver default; stock MAC
provisioning remains pending. Firmware subsystem restart recovery,
calibration-cache persistence, suspend/resume, long connections, both-band
data transfer, and power consumption have not been validated.

Private captures are under `evidence/diagnostic-boot-20261009/`:

- `device-r11-tqftp-failure.raw`: rejected firmware request paths.
- `device-r12-tqftp-normal-boot.raw`: normal-boot firmware service state.
- `device-r12-wlfw-capability.raw`: hardware and firmware capability query.
- `device-r12-wlfw-initialize.raw`: five successful segments and FW_READY.
- `device-r12-wlan-ready-result.raw`: interfaces and first scan.
- `device-r12-wifi-connection-failure.raw`: disconnected state and scans.
- `device-r12-polkit-process-trace.raw`: denied pidfd self-reads.
- `device-r12-polkit-permissions-fix.raw`: corrected proc ownership and
  authorization decisions.
- `device-r12-desktop-polkit-restart.raw`: live authentication agent.
- `device-r12-wifi-connectivity-test.raw` and `device-r12-wifi-https-clock.raw`:
  initial DHCP, DNS, ping, and certificate-validated HTTPS.
- `device-r13-wlan-normal-boot-check.raw`: automatic stock BDF initialization,
  firmware readiness, and supervised authorization/modem services.
- `device-r13-wifi-profile-flags.raw`: saved profile flags without passwords,
  and automatic reconnect while the desktop session was not yet running.
- `device-r13-wifi-connectivity-test.raw` and `device-r13-wifi-https-clock.raw`:
  repeated network tests after the normal reboot.

Earlier tablet timestamps are near the Unix epoch; Chrony synchronized time
once Wi-Fi connected. Capture names record the diagnostic series, not
necessarily the synchronized date of each individual measurement.
