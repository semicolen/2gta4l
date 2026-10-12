#!/bin/sh
set -eu
ls /usr/share/polkit-1/actions/*Sensor* /etc/polkit-1/rules.d/* 2>/dev/null || true
cat /usr/share/polkit-1/actions/net.hadess.SensorProxy.policy
cat /etc/polkit-1/rules.d/*.rules /usr/share/polkit-1/rules.d/*.rules 2>/dev/null || true
python3 -c 'import dbus; from gi.repository import GLib; print("DBUS_GLIB_AVAILABLE")'
ps -eo user,pid,args | grep -E 'xfce4-session|elogind|consolekit|polkit' | grep -v grep || true
ls -l /dev/disk/by-partlabel/persist /dev/adsprpc-smd-secure
apk info | grep -E 'elogind|consolekit|polkit|sensor|python|py3-(dbus|gobject)' || true
timeout 8 ssccli --sensor=accelerometer --timeout=2 | tail -n 16 || true
