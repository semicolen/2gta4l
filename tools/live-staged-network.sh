stty -echo
printf '\nGTA4L_NETWORK_BEGIN\n'
(
for service in modemmanager wpa_supplicant networkmanager; do
    echo "GTA4L_STAGE: starting $service" > /dev/kmsg
    rc-service "$service" start
    echo "Service exit $service: $?"
done
) </dev/null >/var/log/gta4l/staged-network.log 2>&1 &
echo "Network services task: $!"
printf '\nGTA4L_NETWORK_END\n'
stty echo
