#!/bin/sh
set -eu
rc-service modemmanager stop
for pid in $(pidof ModemManager || true); do
    case "$(readlink "/proc/$pid/exe")" in
        /usr/bin/ModemManager|/usr/sbin/ModemManager) ;;
        *) echo 'Unexpected modem daemon executable' >&2; exit 1;;
    esac
    test "$(awk '/^Uid:/ {print $2}' "/proc/$pid/status")" = 0
    kill -TERM "$pid"
done
sleep 1
rc-service modemmanager start
sleep 1
pid=$(pidof ModemManager)
test -n "$pid"
parent=$(awk '/^PPid:/ {print $2}' "/proc/$pid/status")
ps -p "$pid" -o pid,ppid,comm
ps -p "$parent" -o pid,ppid,comm,args
rc-service modemmanager status
echo MODEMMANAGER_SUPERVISION_RESTORE_END
