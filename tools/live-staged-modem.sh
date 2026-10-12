stty -echo
printf '\nGTA4L_MODEM_BEGIN\n'
(
for service in qrtr-ns gta4l-rmtfs gta4l-pd-mapper tqftpserv gta4l-modem; do
    echo "GTA4L_STAGE: starting $service" > /dev/kmsg
    rc-service "$service" start
    echo "Service exit $service: $?"
done
) </dev/null >/var/log/gta4l/staged-modem.log 2>&1 &
echo "Modem services task: $!"
printf '\nGTA4L_MODEM_END\n'
stty echo
