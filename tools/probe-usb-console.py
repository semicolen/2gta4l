#!/usr/bin/env python3
"""Probe the tablet USB interface's normal and diagnostic services."""
import json
import socket

results = {}
for port in (22, 23, 2323, 2424, 2425):
    with socket.socket() as client:
        client.settimeout(2)
        try:
            client.connect(('172.16.42.1', port))
            results[port] = True
        except OSError:
            results[port] = False
print(json.dumps(results))
