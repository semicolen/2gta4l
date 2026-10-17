#!/bin/sh
set -eu
sha256sum -c - <<'CHECKSUMS'
240932fbe8b7f45e48dd10be2701bbcef57bc9d29aa9ad9fd6dfaf805078f6a1  /tmp/gta4l-upload/gcr-3.41.2-r3.apk
b5104d45675a9b61bda22a18fb82252cce0bd55466f13150f1873ef05e4ac80e  /tmp/gta4l-upload/gcr-base-3.41.2-r3.apk
c62b3f49a88ee5e6971eabb30c1805832e5097f4ad2c6606d522e3e3695eaa38  /tmp/gta4l-upload/gcr-lang-3.41.2-r3.apk
32bcc4288ade14d9967201b9524190c5f2342d4bb3c5a86a2f2c972a07466b94  /tmp/gta4l-upload/gnome-keyring-51.1-r0.apk
2245a2447545a2345dd523e2a099e4baaf9579f193bd456d962784af339a71cf  /tmp/gta4l-upload/gnome-keyring-pam-51.1-r0.apk
dbf28abaa3736010908cf433b78756262b27c77ced985ba6ec755b86387f32de  /tmp/gta4l-upload/gnome-keyring-lang-51.1-r0.apk
094db77f29206307a281dc89217029aa048a5ac01dc36dbd4b31d909bc2499a4  /tmp/gta4l-upload/gnome-keyring-openrc-51.1-r0.apk
CHECKSUMS
apk add --no-network /tmp/gta4l-upload/gcr-3.41.2-r3.apk /tmp/gta4l-upload/gcr-base-3.41.2-r3.apk /tmp/gta4l-upload/gcr-lang-3.41.2-r3.apk /tmp/gta4l-upload/gnome-keyring-51.1-r0.apk /tmp/gta4l-upload/gnome-keyring-pam-51.1-r0.apk /tmp/gta4l-upload/gnome-keyring-lang-51.1-r0.apk /tmp/gta4l-upload/gnome-keyring-openrc-51.1-r0.apk
printf "KEYRING_EXACT_VERSIONS_RESTORED\n"
