#!/bin/sh
# Temporarily prevent D-Bus autoactivation racing the diagnostic daemon.
set -eu
service=/usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service
override=/tmp/gta4l-mm-activation.service
log=/var/log/gta4l/modemmanager-debug.log
mkdir -p /run/gta4l-diagnostic
cat > "$override" <<'EOF'
[D-BUS Service]
Name=org.freedesktop.ModemManager1
Exec=/bin/false
User=root
EOF
restore_activation() {
    umount "$service" || true
    dbus-send --system --type=method_call --print-reply \
        --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ReloadConfig || true
}
mount --bind "$override" "$service"
trap restore_activation EXIT
dbus-send --system --type=method_call --print-reply \
    --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ReloadConfig
rc-service modemmanager stop || true
for pid in $(pidof ModemManager); do
    case "$(readlink /proc/$pid/exe)" in
        /usr/sbin/ModemManager|/usr/bin/ModemManager) kill -TERM "$pid" ;;
        *) echo 'Unexpected executable; refusing to stop it'; exit 1 ;;
    esac
done
sleep 1
[ -z "$(pidof ModemManager)" ]
nohup /usr/sbin/ModemManager --debug --log-timestamps --log-file="$log" \
    </dev/null >/var/log/gta4l/modemmanager-launch.log 2>&1 &
pid=$!
echo "$pid" > /run/gta4l-diagnostic/modemmanager.pid
sleep 3
kill -0 "$pid"
mmcli -L
tail -n 130 "$log"
echo MODEMMANAGER_CAPTURE_END
