#!/bin/sh
set -u
for command in pw-dump pw-cli pw-link gst-device-monitor-1.0 gst-launch-1.0 wayland-info snapshot; do
    command -v "$command"
done
python3 - <<'PY'
import gi
for api,version in [('Gst','1.0'),('GstVideo','1.0')]:
    try:
        gi.require_version(api,version)
        print('INTROSPECTION',api,'available')
    except ValueError:print('INTROSPECTION',api,'missing')
PY
