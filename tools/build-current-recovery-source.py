#!/usr/bin/env python3
"""Build the current upstream recovery ZIP locally; credentials stay private."""
from pathlib import Path
import re,subprocess
workspace=Path(__file__).resolve().parents[1]
(workspace/'artifacts/current-recovery-source-ready.json').unlink(missing_ok=True)
password=re.search(r'^Password: (.+)$',(workspace/'artifacts/initial-login.txt').read_text(),re.M)[1]
print('Building current upstream recovery ZIP in WSL',flush=True)
with (workspace/'logs/current-recovery-source-build.log').open('wb') as output:
    result=subprocess.run(['bash',str(workspace/'tools/pmb.sh'),'install',
        '--android-recovery-zip','--recovery-install-partition','userdata',
        '--password',password,'--add','device-samsung-gta4l-nonfree-firmware'],
        stdout=output,stderr=subprocess.STDOUT)
if result.returncode:
    raise SystemExit('Recovery ZIP build failed; see logs/current-recovery-source-build.log (exit '+str(result.returncode)+')')
subprocess.run(['python3',str(workspace/'tools/record-current-recovery-source.py')],check=True)
print('CURRENT_UPSTREAM_RECOVERY_ZIP_BUILT_LOCALLY',flush=True)
