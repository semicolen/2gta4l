"""Record inserted-card detection and read-only filesystem access."""
from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1];evidence=root/'evidence/diagnostic-boot-20261009'
inventory=evidence/'device-r21-sd-card-inventory.raw'
read=evidence/'device-r21-sd-card-read-check.raw'
cards=[json.loads(line.removeprefix('MMC_DEVICE=')) for line in inventory.read_text().splitlines()
       if line.startswith('MMC_DEVICE=')]
card=next(item for item in cards if item['card_type']=='SD')
assert card['device']=='/dev/mmcblk1' and card['bytes']==62542315520
assert card['partitions'][0]['filesystem']=='vfat'
assert 'new ultra high speed SDR104 SDXC card' in inventory.read_text()
text=read.read_text()
assert 'SD_READ_ONLY_MOUNT_OK filesystem=FAT32' in text
assert 'SD_RAW_READ_OK bytes=1048576' in text
assert 'SD_READ_CHECK_PASSED' in text and 'SD_PRIVATE_MOUNT_CLEANED_UP' in text
filesystem=re.search(r'SD_FILESYSTEM bytes=(\d+) free_bytes=(\d+) top_level_entries=(\d+)',text)
report=dict(device='SM-T505',kernel_release=9,device_release=21,
    sd_card=card,hot_insertion_detected=True,read_only_mount_verified=True,
    filesystem='FAT32',filesystem_bytes=int(filesystem[1]),free_bytes=int(filesystem[2]),
    raw_read_bytes=1048576,private_mount_cleanup_verified=True,
    write_test_performed=False,desktop_automount_verified=False,
    evidence={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (inventory,read)})
(root/'artifacts/sd-card-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('SD_CARD_DETECTION_AND_READ_ONLY_ACCESS_VERIFIED')
