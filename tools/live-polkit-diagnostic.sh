#!/bin/sh
set -u
echo '=== Polkit process and log ==='
pidof polkitd || true
logread | grep -Ei 'polkit|ModemManager|sshd.*listen|sshd.*error' | tail -n 100
echo '=== Foreground polkit diagnostic ==='
timeout 8 /usr/lib/polkit-1/polkitd
echo "Polkit diagnostic exit: $?"
echo '=== Modem manager logging after debug enabled ==='
logread | grep -i ModemManager | tail -n 120
echo POLKIT_DIAGNOSTIC_END
