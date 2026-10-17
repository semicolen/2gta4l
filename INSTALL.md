# SM-T505 clean installation through OrangeFox

The refreshed r4 clean-install candidate is documented in
[CURRENT-BUILD.md](CURRENT-BUILD.md), including its verification boundary.
It includes the tested kernel #9, rotation, GPS, camera r2 and audio r3.
Its refreshed rootfs has not been flashed or boot-tested. The working tablet
uses incremental APK and guarded boot updates documented in `PORT-STATUS.md`.
Do not use the clean-install ZIP to update that installation: it formats userdata.

This is a hardware bring-up build. The selected installation replaces Android
**boot and all userdata**. Copy personal Android files elsewhere first.
Partition backups below cannot restore erased Android user data.

The installer preserves OrangeFox recovery, DTBO, dynamic super, bootloader,
modem firmware partitions, EFS and persist. The first modem storage service
also avoids writing NV calibration. Keep the supplied Samsung stock firmware
and OrangeFox available for recovery from a failed boot.

1. Review `PORT-STATUS.md`, the current verification JSON files, and `SHA256SUMS-current` in
   `artifacts/`. The reports verify packaging; they do not prove hardware works.
2. Boot the tablet's existing OrangeFox recovery. If a previous installation
   failed, save its logs and restart OrangeFox recovery before retrying.
   Check `adb -s R9WNC1QG0LJ shell id` reports root.
3. Make the read-only partition backups from PowerShell:

   ```powershell
   python tools\backup-recovery.py --serial R9WNC1QG0LJ
   ```

4. Enable ADB sideload in OrangeFox, then supply the ZIP from PowerShell:

   ```powershell
   adb -s R9WNC1QG0LJ sideload 'C:\Users\darya\Documents\ChatGPT\Postmarket os\artifacts\postmarketOS-SM-T505-OrangeFox-bringup-r4.zip'
   ```

   The ZIP must remain outside internal userdata throughout installation.
   OrangeFox sideload and external SD/USB media satisfy that requirement.
   A copy under `/tmp` also works if recovery has enough free RAM.
   The installer unmounts every userdata alias, including `/sdcard`, before
   partitioning. If it reports userdata busy, unmount Data in OrangeFox and
   retry. It uses regular unmounts and stops on failure. Preflight diagnostics
   are in `/tmp/postmarketos/preflight.log`; installer diagnostics remain in
   `/tmp/postmarketos/pmos.log`.
5. Save OrangeFox's installation log before rebooting. Reboot only after the
   installer reports success. Use the generated `artifacts/initial-login.txt`
   for the `tablet` account and change the password after the first boot.
6. Establish USB networking/SSH and collect logs with `tools/collect-pmos.sh`
   on the tablet as root. This script reads hardware state without activating
   mobile data or altering settings. Save logs locally under `evidence/`.

   The image requests a RNDIS USB network gadget. Its default tablet address is
   `172.16.42.1`; the computer receives `172.16.42.2`. After USB networking is
   active, connect with `ssh tablet@172.16.42.1` using the temporary login.

On a fresh installation, validate boot, display, touch, storage and USB first,
then repeat the hardware checks documented in `PORT-STATUS.md`. Working tests
on the development tablet do not prove the refreshed rootfs's first boot.
Return to OrangeFox to retrieve logs or restore the saved boot image if it cannot boot.

The original ZIP failed on 2026-10-09 because the upstream chroot mount check
could not see OrangeFox's mounted `/data` and `/sdcard`. It wrote a nested MBR
inside userdata, then failed at kpartx; it did not reach filesystem formatting
or boot flashing. Revision 2 repaired those mount checks, which the current
r4 installer retains. Ten read-only boot, recovery
and calibration backups were saved under `artifacts/backups/20261009-214946/`.
