# Local WSL build setup

The package recipes in `port/` are the byte-identical source snapshot used
for the current locally tested port. Run compilation and image assembly in
WSL Ubuntu. The Windows checkout stores sources and exported outputs; use
Ubuntu's native filesystem for pmbootstrap chroots and kernel compilation.

The developer helpers grew alongside the device's incremental bring-up.
They use example roots in this public checkout:

| Example | Purpose |
| --- | --- |
| `/home/pmos/sm-t505-port` | Native WSL source, stock extraction and build root |
| `/mnt/c/postmarketOS-gta4l` / `C:\postmarketOS-gta4l` | Windows checkout and artifacts |
| `/mnt/c/stock-firmware/SM-T505` | Matching Samsung firmware download |

Adjust those roots in the helpers and `tools/pmbootstrap.cfg` to the actual
local directories before running them. The paths in the hardware reports
describe local evidence rather than files published with this branch.

Clone the pmbootstrap, pmaports, OrangeFox, boot-deploy and original port
sources under the native build root's `sources/` directory. Exact revisions
and remote URLs used for the recorded build are in
[`validation/source-revisions.json`](validation/source-revisions.json).
`tools/prepare-wsl.sh` lists the Ubuntu dependencies and initializes the
device helper environment; `tools/fetch-kernel.sh` downloads and verifies
the pinned LineageOS kernel source. `tools/sync-port.sh` copies every local
recipe into pmaports' `device/downstream/` directory.

Use the matching `T505XXS8CXG1` stock firmware locally. The stock extraction,
firmware preparation, sensor extraction and camera runtime preparation
helpers create the private archives referenced by the firmware, sensor and
camera APKBUILDs. These archives are intentionally absent from Git. Read
`tools/extract-stock.py`, `tools/extract-vendor-stock.sh`,
`tools/prepare-firmware.sh`, `tools/prepare-sensor-firmware-package.py` and
`tools/prepare-stock-camera-runtime.py` for their required source directories.

Initialize pmbootstrap for `samsung-gta4l`, Xfce/OpenRC and user `tablet`,
using `tools/pmbootstrap.cfg` after adjusting its paths. Build the required
local recipes before image assembly. `tools/build-image.sh` creates a fresh
build, its private initial-login file and local verification reports.
Its historical output filename uses `r2`; its actual package contents come
from the current recipes. A fresh build's generated initramfs and first boot
require device validation.

The `build-current-*` / `package-current-recovery.py` sequence records the
current r4 candidate by reusing the exact hardware-tested kernel #9 boot.
It requires that locally retained boot image, APKs and verification receipts;
it is not a bootstrap command for an empty clone. Public r4 packaging metadata
and hashes are in [`validation/current-build-verification.json`](validation/current-build-verification.json).
The recorded r4 rootfs has not been flashed.

ADB helpers that previously selected a particular tablet now require
`GTA4L_ADB_SERIAL` in their environment. Set it from `adb devices` for the
tablet being inspected. SSH helpers read the locally generated, Git-ignored
`artifacts/initial-login.txt` and use the USB address `172.16.42.1`.

Historical `live-*`, incremental-update and evidence-recording scripts depend
on the package releases and receipts named in those files. Review their
version and boot-hash guards for the particular installed build. The current
full installer targets internal userdata and replaces boot; its installation
sequence and data-erasure boundary are described in `INSTALL.md`.
