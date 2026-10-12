stty -echo
printf '\nGTA4L_IMAGE_PROBES_BEGIN\n'
cat /proc/uptime
LD_LIBRARY_PATH=/tmp/gta4l-trace/lib /tmp/gta4l-trace/bin/strace -f -s 128 -o /var/log/gta4l/staged-bwrap.log bwrap --unshare-all --die-with-parent --ro-bind / / --dev /dev --proc /proc /bin/true
printf 'Bubblewrap exit: %s\n' "$?"
tail -65 /var/log/gta4l/staged-bwrap.log
printf '\nGLYCIN_VERSION\n'
apk --no-network info -v glycin glycin-loaders gdk-pixbuf gtk+3.0 bubblewrap systemd-utils
printf '\nGTA4L_IMAGE_PROBES_END\n'
stty echo
