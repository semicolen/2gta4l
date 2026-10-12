#!/bin/sh
set -eu
export XDG_RUNTIME_DIR=/run/user/10000
pactl list cards
python3 -u - <<'PY'
from pathlib import Path
path=Path('/home/tablet/.cache/gta4l-audio-startup/persistent-pulse.log')
lines=path.read_text(errors='replace').splitlines() if path.exists() else []
for line in [line for line in lines if any(key in line.lower() for key in ('ucm','profile','alsa-card','failed','error','alsa-sink','ignore','default'))][:130]:print('PERSISTENT_PROFILE_LOG='+line)
print('PERSISTENT_PROFILE_STATE_END')
PY
