# SM-T505 microSD check

The running kernel #9 detects hot insertion of the tested SDXC card through
the native SDHCI controller. The card appears as `/dev/mmcblk1`, with one
FAT32 partition at `/dev/mmcblk1p1`. The kernel reports SDR104 mode.

Reported device capacity is 62,542,315,520 bytes (58.2 GiB). The filesystem
reports 31,804,817,408 bytes free at the time of testing.

A private mount namespace mounted the filesystem read-only, verified its
read-only flag, enumerated directory metadata without recording filenames and
successfully read 1 MiB of partition metadata. The mount was removed afterward.
No repair, formatting or write test was performed. Desktop automount and card
removal/reinsertion are not covered by this check.

Evidence is recorded in `artifacts/sd-card-verification.json` and
`evidence/diagnostic-boot-20261009/device-r21-sd-card-inventory.raw` /
`device-r21-sd-card-read-check.raw`. No card contents were copied off the tablet.
