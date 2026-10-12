# SM-T505 Bluetooth bring-up

The stock APACHE/WCN3988 controller works through the downstream GENI UART
and a userspace firmware bootstrap followed by the Linux H4 transport.
The user paired a RAPOO BT4.0 mouse and confirmed pointer movement and clicks.
A 25-second recording captured 334 relative-motion events and three button
press/release pairs. This is a BLE/UHID mouse; classic HIDP has not yet been
exercised with a physical device.

## Controller initialization

The device uses `/dev/ttyHS0` at GENI MMIO `4a8c000` and vendor `bt_power`
rfkill. The matching Samsung firmware is `apbtfw11.tlv` and `apnv11.bin`.
Hashes, TLV bounds, product, ROM, SoC revision and patched version are checked.
The stock ROM reports product `0x0a`, ROM `0x0201`, SoC `0x40020150`; after
the exact signed patch it reports patch 2 and SoC `0x40020140`.

The transfer uses 3 Mbaud with RTS/CTS and a downstream UART clock vote.
The complete Bluetooth TLV is selected from the stock Bluetooth/FM NVM
container. Only the address and transport/deep-sleep settings are changed
in the bytes sent to controller RAM. The signed patch, firmware files and
calibration partitions remain unchanged. The original address is read from
`sec_efs` using read-only `debugfs` without `-w`, then checked against the
controller's address. No address is embedded in the source or bootstrap log.

Initialization follows the stock UART power pulse and baud sequence.
Controller diagnostic logging is disabled and bounded queued diagnostic
ACL records are discarded before H4 attachment. A later unknown diagnostic
ACL handle warning was still observed in the staged test; clean kernel logs
are not claimed.

The downstream QCA tty setup dereferences a missing serdev object. Kernel #9
rejects that unsupported path early; the port uses H4 after the guarded
bootstrap. The earlier Bluetooth HCI socket repair remains included.

## Packaging and networking

Kernel #9 (`4.19.300-r8`) restores the vendor-disabled BNEP/HIDP Makefile
entries, enables both modules, and enables HIDRAW. All 35 previous driver
module paths remain, with `bnep.ko` and `hidp.ko` added. Device r15 includes
`bluetooth-gta4l` and explicitly requires the NetworkManager Bluetooth plugin.
OpenRC supervises the bootstrap and enables it at normal startup. Pairing
records are preserved during the incremental upgrade.

All packages and the boot-only OrangeFox update were built locally in WSL
Ubuntu. The image retains the tested #8 ramdisk and all DTBs and writes only
boot. The historical full installer has not been rebuilt with these changes.

One normal boot on kernel #9/device r15 confirms supervised automatic radio
startup, controller power, preserved pairings, and automatic RAPOO mouse
reconnection. The user confirmed the desktop, touch and mouse after this boot.
Ten raw sockets each for HCI, BNEP and HIDP were created and closed successfully.
The graphical login, WLAN, ADSP and ModemManager services remained running;
the logged-in desktop detected its single PulseAudio speaker card and sink.

The user-paired Lenovo laptop advertises NAP. The tablet now has an active
NetworkManager `panu` connection named `gta4l-lenovo-pan`, with DHCP address,
gateway and DNS supplied by the laptop. NetworkManager identifies the device
by the peer Bluetooth address; its active IP interface is `bnep0`.
A DNS query and certificate-validated HTTPS request both used sockets bound
to `bnep0`. The response was HTTP 200, with 7,281 received and 2,656 transmitted
bytes during the test. Wi-Fi stayed connected, but could not carry these
explicitly bound requests.

The profile is manually activated and uses IPv4 route metric 700. Wi-Fi remains
preferred while both links are available. To reconnect to the prepared laptop:

```sh
nmcli connection up gta4l-lenovo-pan
```

The laptop must keep Bluetooth internet sharing enabled. PAN reconnect and
long transfers have not yet been tested.

## Validation and limits

The stock-NVM test checks that only tags 2, 17 and 27 change, the input
container remains unchanged, and malformed containers are rejected.
Boot checks validate the Samsung v2 header, ARM64 Image, embedded config,
12 DTBs and SHA256. Package checks verify source/APK agreement, dependencies
and all 37 modules. Build checks do not establish physical classic HID,
Bluetooth audio or suspend functionality.

IBS and controller deep sleep are disabled, and the UART clock stays voted
on. Bluetooth power saving and system suspend remain unverified.
The existing duplicate-proc-entry and I2C PMIC deferred-probe warnings remain
in kernel logs; earlier kernel evidence contains the same warnings. No panic
occurred during the completed Bluetooth startup/socket/PAN tests.

Private evidence is under `evidence/diagnostic-boot-20261009/`, including
`device-r14-bt-final-start-ready.raw`, `device-r14-bt-final-discovery.raw`,
`device-r14-bt-mouse-state.raw`, `device-r14-bt-mouse-events.raw`, and
`device-r14-bt-lenovo-paired-state-v2.raw`, `device-r15-bt-normal-boot-check.raw`,
`device-r15-bt-pan-internet-check.raw`, and `device-r15-bt-post-test-state.raw`.
Package and boot hashes are in
`artifacts/bluetooth-packages-verification.json` and
`artifacts/bluetooth-fix-verification.json`.

References: [Linux btqca firmware protocol](https://github.com/torvalds/linux/blob/v6.6/drivers/bluetooth/btqca.c),
[WCN3988 support](https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/stable-queue/+/refs/tags/v6.12.41/releases/5.15.162/bluetooth-btqca-add-wcn3988-support.patch),
[NetworkManager Bluetooth settings](https://networkmanager.dev/docs/api/latest/settings-bluetooth.html),
and [BlueZ Network API](https://github.com/bluez/bluez/blob/master/doc/org.bluez.Network.rst).
