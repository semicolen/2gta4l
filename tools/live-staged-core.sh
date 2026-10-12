stty -echo
printf '\nGTA4L_CORE_BEGIN\n'
(
for service in dbus cgroups elogind haveged sshd; do
    echo "GTA4L_STAGE: starting $service" > /dev/kmsg
    rc-service "$service" start
    echo "Service exit $service: $?"
done
) </dev/null >/var/log/gta4l/staged-core.log 2>&1 &
echo "Core services task: $!"
printf '\nGTA4L_CORE_END\n'
stty echo
