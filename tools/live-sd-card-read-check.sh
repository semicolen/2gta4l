#!/bin/sh
set -eu
test "$(cat /sys/class/block/mmcblk1/device/type)" = SD
test -b /dev/mmcblk1p1
unshare -m /bin/sh -c '
    set -eu
    mount --make-rprivate /
    directory=$(mktemp -d /run/gta4l-sd-read.XXXXXX)
    mounted=false
    cleanup() {
        if [ "$mounted" = true ]; then umount "$directory"; fi
        rmdir "$directory"
    }
    trap cleanup EXIT
    mount -t vfat -o ro,nosuid,nodev,noexec /dev/mmcblk1p1 "$directory"
    mounted=true
    python3 - "$directory" <<"PY"
from pathlib import Path
import os,sys,time
directory=Path(sys.argv[1])
lines=Path("/proc/self/mountinfo").read_text().splitlines()
record=next(line.split() for line in lines if line.split()[4]==str(directory))
assert record[2]==Path("/sys/class/block/mmcblk1p1/dev").read_text().strip()
assert "ro" in record[5].split(",")
separator=record.index("-")
assert record[separator+1]=="vfat"
info=os.statvfs(directory)
assert info.f_flag & os.ST_RDONLY
count=sum(1 for _ in directory.iterdir())
with open("/dev/mmcblk1p1","rb",buffering=0) as partition:
    header=partition.read(512)
    assert header[510:512]==bytes([0x55,0xaa])
    fat_type=header[82:90].decode("ascii",errors="replace").strip()
    partition.seek(0);started=time.monotonic()
    data=partition.read(1024*1024)
    assert len(data)==1024*1024
    elapsed=time.monotonic()-started
print("SD_READ_ONLY_MOUNT_OK filesystem="+fat_type)
print("SD_FILESYSTEM bytes=%d free_bytes=%d top_level_entries=%d" %
      (info.f_blocks*info.f_frsize,info.f_bavail*info.f_frsize,count))
print("SD_RAW_READ_OK bytes=%d seconds=%.4f" % (len(data),elapsed))
print("SD_READ_CHECK_PASSED")
PY
'
printf 'SD_PRIVATE_MOUNT_CLEANED_UP\n'
