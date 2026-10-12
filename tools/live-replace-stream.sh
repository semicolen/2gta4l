stty -echo
printf '\nGTA4L_STREAM_STOP_BEGIN\n'
for executable in /proc/[0-9]*/exe; do
    case "$(readlink "$executable" 2>/dev/null)" in
        '/tmp/gta4l-kmsg-stream'|'/tmp/gta4l-kmsg-stream (deleted)')
            pid="${executable#/proc/}"; pid="${pid%/exe}"
            printf 'Stopping diagnostic stream PID %s\n' "$pid"
            kill "$pid"
            ;;
    esac
done
printf '\nGTA4L_STREAM_STOP_END\n'
stty echo
