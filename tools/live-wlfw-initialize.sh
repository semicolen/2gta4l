#!/bin/sh
set -eu
binary=/tmp/gta4l-upload/wlfw-initialize
sha256sum -c - <<'HASHES'
e938be870ce1f7a341aaaab93bf830acd53e39566978ec85a3dd51f640422bfd  /tmp/gta4l-upload/wlfw-initialize
a18a7fce954ca5b4e7758a4853844d1bdc48e9dbec793c54356e4667c44834e8  /lib/firmware/postmarketos/wlan/qca_cld/bdwlan.bin
HASHES
chmod 700 "$binary"
endpoint=$(timeout 5 qrtr-lookup | awk '$1 == 69 && $2 == 1 && $3 == 0 {print $4, $5; exit}')
[ -n "$endpoint" ]
set -- $endpoint
echo "Initializing WLAN firmware at QRTR node $1, port $2 with matching stock board data"
timeout -k 2 30 "$binary" "$1" "$2" /lib/firmware/postmarketos/wlan/qca_cld/bdwlan.bin
