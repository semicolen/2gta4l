stty -echo
printf '\nGTA4L_MM_DEBUG_BEGIN\n'
rc-service modemmanager stop
for pid in $(pidof ModemManager); do
    case "$(readlink /proc/$pid/exe)" in
        /usr/sbin/ModemManager|/usr/bin/ModemManager) ;;
        *) exit 1 ;;
    esac
    kill -TERM "$pid"
done
sleep 1
[ -z "$(pidof ModemManager)" ] || exit 1
nohup ModemManager --debug --log-timestamps --log-file=/var/log/gta4l/modemmanager-debug.log </dev/null >/var/log/gta4l/modemmanager-launch.log 2>&1 &
echo "$!" > /run/gta4l-diagnostic/modemmanager.pid
echo "Diagnostic ModemManager PID: $!"
printf '\nGTA4L_MM_DEBUG_END\n'
stty echo
