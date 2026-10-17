#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
for event in Path('/sys/class/input').glob('event*'):
    if (event/'device/name').read_text().strip()!='himax-touchscreen':continue
    print('HIMAX',event.name)
    for name in ('properties','capabilities/ev','capabilities/key','capabilities/rel','capabilities/abs'):
        raw=(event/'device'/name).read_text().strip()
        mask=sum(int(part,16)<<(64*i) for i,part in enumerate(reversed(raw.split())))
        print(name,repr(raw),'set bits',[bit for bit in range(mask.bit_length()) if mask & (1<<bit)])
PY
