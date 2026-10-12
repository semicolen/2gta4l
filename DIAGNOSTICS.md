# SM-T505 diagnostic boot

`artifacts/postmarketOS-SM-T505-OrangeFox-diagnostic-boot.zip` is a boot-only
update for the installed bring-up image. It checks the SM-T505/gta4l identity,
96 MiB boot partition, existing image hash, embedded image hash and readback.
It writes only boot, without repartitioning or formatting userdata. OrangeFox
and the installed Linux system remain available.

Revision 2 is `artifacts/postmarketOS-SM-T505-OrangeFox-diagnostic-boot-r2.zip`.
It guards against the first diagnostic boot image's hash and adds
`pmos.debug-shell panic=15`. Each boot pauses before mounting Linux, exposing
USB serial and telnet on the direct USB link. `pmos_continue_boot` resumes
startup. A panic then warm-reboots after 15 seconds and returns to this pause,
allowing pstore collection without a manual power reset. This is a diagnostic
configuration; it does not automatically proceed to the desktop.

Revision 3 is `artifacts/postmarketOS-SM-T505-OrangeFox-diagnostic-boot-r3.zip`.
It preserves the debug USB gadget when leaving the debug shell, avoiding its
intentional disconnect/rebind. Its installer accepts only the verified r2
diagnostic boot. The kernel and DTBs are unchanged. A separate static ARM64
read-only TCP recorder can capture `/dev/kmsg` on the direct USB interface
without depending on a terminal. It binds only to 172.16.42.1:2425.

On 2026-10-10 the staged tests identified the primary crash in the vendor HCI
socket constructor, triggered by bluetoothd. The patched kernel has built
locally in WSL. `artifacts/postmarketOS-SM-T505-OrangeFox-hci-fix.zip` is the
guarded boot-only update from diagnostic r3. It preserves that ramdisk, all
12 DTBs and all 35 driver modules. OrangeFox install/readback and ten raw HCI
socket creations passed on #4-postmarketOS, followed by staged default startup
with Bluetooth enabled. Controller/radio functionality and unattended startup
remain unverified.
See `evidence/diagnostic-boot-20261009/HCI-CRASH-REPORT.md` for
the captured primary trace and the separate desktop compatibility failure.
The boot-stage sysctl service overrides `panic=15` with 120 seconds.

For diagnostic revisions 1–3, the kernel, modules and DTBs are unchanged.
The HCI fix replaces only the built-in kernel. The initramfs overlay starts a
static ARM64 kernel-log collector immediately before switch_root. The collector
was exercised against the tablet's recovery kernel, including graceful exit.
The command line adds tty0 console output, verbose initramfs logging and
uncompressed pstore records. OpenRC logging is enabled on the next Linux boot.

Persistent files:

- `/var/log/gta4l/initramfs.log`
- `/var/log/gta4l/pre-handoff-dmesg.log`
- `/var/log/gta4l/kernel-live.log`
- `/var/log/gta4l/collector.log`
- `/var/log/gta4l/cmdline.txt`
- `/var/log/rc.log`

The previous diagnostic boot's kernel/initramfs logs are retained with
`.previous` suffixes. The original OpenRC configuration is saved as
`/var/log/gta4l/rc.conf.before-debug`. Recovery collection uses a read-only
loop device and ext4 `ro,noload`, without journal replay.

Install this ZIP from OrangeFox, then boot System once. If it resets, return
to OrangeFox while keeping USB connected so the logs can be collected.
The package refuses installation if boot no longer matches the original
bring-up image; it does not reboot automatically.

To restore normal boot, write the preserved `artifacts/boot.img` to the boot
partition through recovery and verify its readback. Do not reinstall the full
bring-up ZIP just to undo diagnostics: that installer formats userdata.
Restore `/etc/rc.conf` from its saved copy to disable the added OpenRC logging.

The diagnostic image is not a boot-loop fix or proof that hardware works.
Verification reports are saved in `artifacts/diagnostic-*-verification.json`
and `artifacts/diagnostic-overlay-check.json`.
