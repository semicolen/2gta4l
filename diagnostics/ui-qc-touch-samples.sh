#!/bin/sh
set -u
pgrep -af ui-qc-touch-targets.py || true
cat /tmp/gta4l-touch-targets.log
if [ -f /home/tablet/.cache/gta4l-ui-qc/touch-samples.json ]; then
    cat /home/tablet/.cache/gta4l-ui-qc/touch-samples.json
fi
