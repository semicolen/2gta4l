#!/bin/sh
set -u
mmcli -L
mmcli -m 0 --output-keyvalue | grep -E 'state|access-technologies|signal|current-modes|supported-modes|current-bands|registration-state|operator-name|equipment-identifier' | grep -v equipment-identifier
ip -d link show rmnet_ipa0
echo MODEM_SUMMARY_END
