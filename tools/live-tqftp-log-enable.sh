#!/bin/sh
set -eu
[ "$(id -u)" -eq 0 ]
mkdir -p /var/log/gta4l
if [ -e /etc/conf.d/tqftpserv ]; then
    echo 'Existing firmware server configuration; refusing to overwrite'
    exit 1
fi
cat > /etc/conf.d/tqftpserv <<'EOF'
# Temporary bounded bring-up diagnostics; no firmware path changes.
command_args="-d"
output_log="/var/log/gta4l/tqftpserv.log"
error_log="/var/log/gta4l/tqftpserv.log"
EOF
chmod 644 /etc/conf.d/tqftpserv
rc-service tqftpserv restart
sleep 3
tail -c 12000 /var/log/gta4l/tqftpserv.log 2>/dev/null || true
echo TQFTP_LOG_ENABLED
