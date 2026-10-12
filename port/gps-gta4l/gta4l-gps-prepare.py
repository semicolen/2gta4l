#!/usr/bin/python3
# SPDX-License-Identifier: MIT
"""Make the downstream LOC engine available without enabling GPS gathering."""
from pathlib import Path
import os
import subprocess
import sys
import time

def main():
    if os.geteuid()!=0:
        sys.exit('GPS engine preparation requires root')
    # This helper belongs to the SM-T505 package, never a generic modem install.
    model=Path('/proc/device-tree/model').read_bytes().rstrip(b'\0').decode()
    if 'Bengal' not in model:
        sys.exit('Unexpected device tree; refusing GPS engine preparation')
    ready=Path('/run/gta4l-gps-ready')
    deadline=time.monotonic()+60
    attempts=0
    while time.monotonic()<deadline:
        attempts+=1
        try:
            # The downstream MPSS exports LOC v2 on QRTR node 0. A successful
            # operation-mode query proves that the service is ready to respond.
            mode=subprocess.run(['qmicli','-d','qrtr://0','--loc-get-operation-mode'],
                capture_output=True,text=True,timeout=9)
            if mode.returncode==0:
                result=subprocess.run(['qmicli','-d','qrtr://0','--loc-set-engine-lock=none'],
                    capture_output=True,text=True,timeout=9)
                if result.returncode==0:
                    ready.write_text('LOC engine available; gathering remains client-controlled\n')
                    ready.chmod(0o600)
                    print(f'GPS engine available after {attempts} attempt(s); tracking not enabled')
                    return
        except subprocess.TimeoutExpired:
            pass
        time.sleep(2)
    sys.exit('LOC engine preparation timed out; GPS availability is unverified')

if __name__=='__main__': main()
