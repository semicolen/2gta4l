#!/bin/sh
set -eu
binary=/tmp/gta4l-upload/wlfw-capability-query
echo '67b79df9a7dbcc0922a556b88a486edf24df11cca96a43cec3fab730e82e7274  /tmp/gta4l-upload/wlfw-capability-query' | sha256sum -c -
chmod 700 "$binary"
endpoint=$(timeout 5 qrtr-lookup | awk '$1 == 69 && $2 == 1 && $3 == 0 {print $4, $5; exit}')
[ -n "$endpoint" ]
set -- $endpoint
echo "Querying WLAN firmware at QRTR node $1, port $2"
timeout 8 "$binary" "$1" "$2"
