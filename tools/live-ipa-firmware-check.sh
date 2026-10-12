#!/bin/sh
set -u
echo '=== IPA device-tree firmware selection ==='
for file in /sys/firmware/devicetree/base/soc/*ipa*/*fw* /sys/firmware/devicetree/base/soc/*ipa*/*firmware*; do
    [ -f "$file" ] || continue
    printf '%s: ' "$file"
    tr '\000' '\n' < "$file"
done
echo '=== Signed IPA firmware ==='
ls -l /lib/firmware/postmarketos/*ipa* /lib/firmware/postmarketos/*scuba* 2>/dev/null
echo IPA_FIRMWARE_CHECK_END
