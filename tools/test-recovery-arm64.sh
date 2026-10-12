#!/bin/busybox ash
# Run only checks and regular-file partitioning in the recovery chroot.
set -eu
export PATH=/bin
export LD_LIBRARY_PATH=/lib
. /gta4l-partition-functions.sh
ui_print() { printf '%s\n' "$1"; }
awk '$3 == "259:48" {found=1} END {exit !found}' /proc/1/mountinfo
if gta4l_assert_userdata_idle; then
    echo 'Expected the currently mounted Android userdata to be rejected'
    exit 1
fi
echo 'PASS: chroot detects mounted OrangeFox userdata and refuses partitioning'
trap 'rm -f /gta4l-test-partition-table.img' EXIT
gta4l_make_partition_table 23484415488 /gta4l-test-partition-table.img
parted -m -s /gta4l-test-partition-table.img unit s print
echo 'PASS: tablet ARM64 tools produce and validate the full-size sparse MBR'
