#!/usr/bin/env python3
"""Check a generated Android boot image against the measured SM-T505 layout."""
from pathlib import Path
import argparse
import gzip
import hashlib
import json
import struct
from fdt_metadata import summarize

p = argparse.ArgumentParser()
p.add_argument('image', type=Path)
p.add_argument('report', type=Path)
a = p.parse_args()
d = a.image.read_bytes()
assert d[:8] == b'ANDROID!', 'Missing boot image magic'
ks, ka, rs, ra, ss, sa, ta, page, ver, osv = struct.unpack_from('<10I', d, 8)
assert (ka, ra, ta, page, ver) == (0x8000, 0x02000000, 0x01e00000, 4096, 2), 'Wrong boot addresses/header'
align = lambda n: (n + page - 1) // page * page
rdtos, rdtoo, hs = struct.unpack_from('<IQI', d, 1632)
ds, da = struct.unpack_from('<IQ', d, 1648)
assert da == 0x01f00000 and ds > 0, 'Wrong/missing DTB'
assert not rdtos, 'Boot image unexpectedly includes a recovery DTBO'
ko = page
ro = ko + align(ks)
dto = ro + align(rs) + align(ss) + align(rdtos)
assert 0 < ks and 0 < rs and dto + ds <= len(d) <= 100663296, 'Payload exceeds boot partition'
kernel = gzip.decompress(d[ko:ko+ks])
assert kernel[0x38:0x3c] == b'ARM\x64', 'Kernel is not an ARM64 Image'
pos = kernel.find(b'Linux version ')
assert pos >= 0, 'No kernel version string'
version = kernel[pos:kernel.find(b'\0', pos)].decode(errors='replace')
assert '4.19.300' in version and 'postmarketOS' in version, 'Unexpected kernel build'
config_start = kernel.find(b'IKCFG_ST\x1f\x8b\x08')
assert config_start >= 0, 'Embedded kernel configuration missing'
config_end = kernel.find(b'IKCFG_ED', config_start + 8)
assert config_end > config_start, 'Invalid embedded kernel configuration'
config = gzip.decompress(kernel[config_start + 8:config_end]).decode()
required_config = ['DEVTMPFS', 'FHANDLE', 'PID_NS', 'BLK_DEV_INITRD', 'EXT4_FS',
                   'DM_CRYPT', 'QRTR', 'QRTR_SMD', 'UIO_MSM_SHAREDMEM',
                   'BT_HCIUART', 'BT_HCIUART_H4', 'BT_HCIUART_QCA',
                   'USB_CONFIGFS_ECM', 'USB_CONFIGFS_RNDIS']
for option in required_config:
    assert f'CONFIG_{option}=y\n' in config, 'Missing built-in kernel option: ' + option
assert 'CONFIG_QCA_CLD_WLAN=m\n' in config, 'WLAN module configuration missing'
dtbs = []
off = dto
while off < dto + ds:
    magic, total = struct.unpack_from('>II', d, off)
    assert magic == 0xd00dfeed and total >= 40 and off + total <= dto + ds, 'Invalid concatenated DTB'
    dtbs.append(total)
    off += total
assert off == dto + ds, 'Unparsed DTB bytes'
board = d[48:64].split(b'\0')[0].decode()
assert board == 'SRPTC24A008', 'Wrong Samsung board'
cmdline = (d[64:576] + d[608:1632]).split(b'\0')[0].decode()
assert 'firmware_class.path=/lib/firmware/postmarketos' in cmdline, 'Missing firmware path'
report = dict(image=a.image.name, sha256=hashlib.sha256(d).hexdigest(), bytes=len(d),
              kernel_bytes=ks, ramdisk_bytes=rs, dtb_bytes=ds, dtb_count=len(dtbs),
              header_version=ver, page_size=page, board=board, kernel_version=version,
              cmdline=cmdline, checks_passed=True, runtime_verified=False)
report['verified_kernel_options'] = required_config
report['device_trees'] = summarize(d[dto:dto+ds])
stock_trees = summarize(Path('/home/ark/sm-t505-port/stock/boot/dtb.img').read_bytes())
stock_soc_ids = {tree['qcom,msm-id'][i] for tree in stock_trees if 'qcom,msm-id' in tree
                 for i in range(0, len(tree['qcom,msm-id']), 2)}
built_soc_ids = {tree['qcom,msm-id'][i] for tree in report['device_trees'] if 'qcom,msm-id' in tree
                 for i in range(0, len(tree['qcom,msm-id']), 2)}
assert stock_soc_ids & built_soc_ids, 'Compiled DTBs have no SoC ID in common with stock boot'
report['soc_ids_matching_stock'] = sorted(stock_soc_ids & built_soc_ids)
a.report.write_text(json.dumps(report, indent=2) + '\n')
print('Validated ARM64 boot image:', len(d), 'bytes,', len(dtbs), 'DTBs, header v2, SHA256', report['sha256'])
