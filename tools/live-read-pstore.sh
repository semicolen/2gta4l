stty -echo
printf '\nGTA4L_STATE_BEGIN\n'
cat /proc/uptime /proc/sys/kernel/panic
ls -l /sys/fs/pstore
printf '\nGTA4L_PSTORE_BEGIN\n'
for file in /sys/fs/pstore/*; do [ -f "$file" ] || continue; printf '\nGTA4L_FILE:%s\n' "$file"; sha256sum "$file"; base64 "$file"; printf '\nGTA4L_FILE_END\n'; done
printf '\nGTA4L_PSTORE_END\n'
stty echo
