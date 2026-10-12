stty -echo
printf '\nGTA4L_REST_BEGIN\n'
rc-service lightdm stop
(
for service in swapfile postmarketos-zram-swap nftables chronyd rfkill sleep-inhibitor routewrangler brightnessctl udev-postmount bluetooth local; do
    echo "GTA4L_STAGE: starting $service" > /dev/kmsg
    rc-service "$service" start
    echo "Service exit $service: $?"
    sync
done
) </dev/null >/var/log/gta4l/staged-rest.log 2>&1 &
echo "Remaining services task: $!"
printf '\nGTA4L_REST_END\n'
stty echo
