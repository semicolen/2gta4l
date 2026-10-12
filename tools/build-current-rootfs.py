#!/usr/bin/env python3
"""Rebuild the local rootfs with current port APKs; never flash the tablet."""
from pathlib import Path
import json,re,subprocess,sys
workspace=Path(__file__).resolve().parents[1]
base=Path('/home/pmos/sm-t505-port')
tools=workspace/'tools'
login=(workspace/'artifacts/initial-login.txt').read_text()
build_password=re.search(r'^Password: (.+)$',login,re.M)[1]
assert re.search(r'^User: tablet$',login,re.M)

def step(title,command,log_name):
    print(title,flush=True)
    with (workspace/'logs'/log_name).open('wb') as log:
        result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:
        # Do not expose argv: install's arguments contain the login password.
        raise SystemExit(title+' failed; see logs/'+log_name+' (exit '+str(result.returncode)+')')

step('Preparing current source checksums',['python3',str(tools/'configure-port.py')],'current-configure.log')
step('Stopping old local build mounts',['bash',str(tools/'pmb.sh'),'shutdown'],'current-shutdown.log')
step('Preparing ARM64 build emulation',['sh',str(tools/'ensure-wsl-arm64-emulation.sh')],'current-emulation.log')
step('Building fresh-install device r22',['bash',str(tools/'sync-port.sh'),'build','--lax',
     'device-samsung-gta4l','--arch','aarch64','--force'],'current-device-r22-build.log')
step('Creating current device rootfs',['bash',str(tools/'pmb.sh'),'install','--no-image',
     '--password',build_password,'--add','device-samsung-gta4l-nonfree-firmware'],
     'current-rootfs-build.log')
step('Verifying current rootfs',['python3',str(tools/'verify-rootfs.py'),'--report',
     str(workspace/'artifacts/rootfs-current-verification.json')],'current-rootfs-check.log')
print('CURRENT_ROOTFS_LOCAL_WSL_BUILD_AND_VALIDATION_PASSED',flush=True)
