#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import json,re,subprocess

def value(path):
    try:return path.read_text().strip()
    except (FileNotFoundError,OSError):return None

cards=[]
for path in sorted(Path('/sys/class/block').glob('mmcblk*')):
    if not re.fullmatch(r'mmcblk\d+',path.name):continue
    kind=value(path/'device/type')
    entry={'device':'/dev/'+path.name,'card_type':kind,'name':value(path/'device/name'),
           'bytes':int(value(path/'size') or '0')*512,
           'read_only':value(path/'ro'),'removable':value(path/'removable'),
           'partitions':[]}
    for partition in (sorted(Path('/sys/class/block').glob(path.name+'p*')) if kind=='SD' else []):
        node='/dev/'+partition.name
        probe=subprocess.run(['blkid','-p','-s','TYPE','-o','value',node],capture_output=True,text=True,timeout=5)
        entry['partitions'].append({'device':node,'bytes':int(value(partition/'size') or '0')*512,
                                    'filesystem':probe.stdout.strip() or None,
                                    'probe_exit':probe.returncode,'major_minor':value(partition/'dev')})
    if kind=='SD':cards.append(entry)
    print('MMC_DEVICE='+json.dumps(entry,sort_keys=True))
print('SD_CARDS_DETECTED='+str(len(cards)))
mounts=Path('/proc/self/mountinfo').read_text().splitlines()
for card in cards:
    ids={p['major_minor'] for p in card['partitions']}|{value(Path('/sys/class/block')/Path(card['device']).name/'dev')}
    for line in mounts:
        fields=line.split()
        if fields[2] in ids:
            print('SD_MOUNT='+line)
kernel=subprocess.run(['dmesg'],capture_output=True,text=True,timeout=5).stdout.splitlines()
for line in [line for line in kernel if 'Kernel command line:' not in line and re.search(r'mmc[1-9]|mmcblk[1-9]|sdhci',line,re.I)][-70:]:
    print('SD_KERNEL='+line)
print('SD_CARD_INVENTORY_END')
PY
