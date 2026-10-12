#!/bin/sh
set -eu
mmcli -m 0 -J | python3 -c 'import json,sys; v=json.load(sys.stdin)["modem"]["generic"]; print("plugin="+str(v.get("plugin"))); print("state="+str(v.get("state"))); print("ports="+str(v.get("ports")))'
