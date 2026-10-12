printf '\nGTA4L_CONTINUE_BEGIN\n'
ls -l /gta4l-bootlog /hooks-cleanup/99-gta4l-diagnostics.sh
cat /proc/uptime
pmos_continue_boot
printf '\nGTA4L_CONTINUE_REQUESTED\n'
