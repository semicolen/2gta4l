#!/bin/sh
set -eu
python3 -u - <<'PY'
from pathlib import Path
import collections,json,subprocess
path=Path('/home/tablet/.cache/gta4l-audio-startup/timer-pulse.log')
need=('underrun','latency','watermark','xrun','alsa woke','failed','error','suspend','buffer','rewind','rewrote')
count=collections.Counter();selected=[]
if path.exists():
    with path.open(errors='replace') as log:
        for line in log:
            low=line.lower()
            for key in need:
                if key in low:count[key]+=1
            if any(key in low for key in need) and len(selected)<140:selected.append(line.strip())
    print('PULSE_STARTUP_LOG_BYTES='+str(path.stat().st_size))
    print('PULSE_STARTUP_LOG_COUNTS='+json.dumps(count,sort_keys=True))
    for line in selected:print('PULSE_STARTUP_LOG='+line)
print('AUDIO_STARTUP_LOG_END')
PY
