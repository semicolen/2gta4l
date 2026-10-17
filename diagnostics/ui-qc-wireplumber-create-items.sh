#!/bin/sh
set -eu
find /usr/share/wireplumber/scripts -maxdepth 2 -type f | grep -E 'node/|linking/'
for path in /usr/share/wireplumber/scripts/node/create-item.lua /usr/share/wireplumber/scripts/node/state-default-nodes.lua; do
    [ ! -f "$path" ] || cat "$path"
done
