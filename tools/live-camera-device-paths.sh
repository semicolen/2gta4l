#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os
import stat
for pattern in ['kgsl*','kgsl/*','adsprpc*','fastrpc*','dri/*']:
    for path in Path('/dev').glob(pattern):
        s = path.stat()
        print(str(path)+' -> '+str(path.resolve())+' mode='+oct(s.st_mode)+
              (' major=%d minor=%d' % (os.major(s.st_rdev), os.minor(s.st_rdev))
               if stat.S_ISCHR(s.st_mode) else ''))
print('CAMERA_DEVICE_PATHS_END')
PY
