#!/bin/sh
# Downstream ipa3_write() queues the signed firmware load on a nonempty write.
set -eu
[ -c /dev/ipa ]
echo 'GTA4L_TEST: vendor IPA firmware activation' > /dev/kmsg
printf '1\n' > /dev/ipa
sleep 3
ip -br link
dmesg | grep -Ei 'ipa|rmnet|firmware' | tail -n 100
echo IPA_ACTIVATION_END
