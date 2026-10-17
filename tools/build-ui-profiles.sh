#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
for package in postmarketos-ui-plasma-mobile postmarketos-ui-plasma-desktop; do
    cp -a "$WORKSPACE/ui-profiles/aports/$package/." "$ROOT/sources/pmaports/main/$package/"
    bash "$WORKSPACE/tools/pmb.sh" build --lax "$package" --arch aarch64 --force
done
echo LOCAL_OPENRC_PLASMA_PROFILES_BUILT
