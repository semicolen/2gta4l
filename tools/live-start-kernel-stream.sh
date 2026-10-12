printf '\nGTA4L_STREAM_SETUP_BEGIN\n'
cat > /tmp/gta4l-kernel-stream.sh <<'EOF'
#!/bin/busybox ash
exec cat /dev/kmsg
EOF
chmod 700 /tmp/gta4l-kernel-stream.sh
telnetd -b 172.16.42.1:2424 -l /tmp/gta4l-kernel-stream.sh
printf '\nGTA4L_STREAM_SETUP_END\n'
