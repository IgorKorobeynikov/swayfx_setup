#!/bin/sh

REQUIRED_VER="10.47"
if ! pkg info -q pcre2 | grep -q "$REQUIRED_VER"; then
    echo "pcre2 version $REQUIRED_VER is required. Installing..."
    pkg install -y pcre2-$REQUIRED_VER
    exit 1
fi

if ! pgrep -x seatd >/dev/null; then
    echo "seatd is not running, starting..."
    service seatd onestart
fi

SOCKET="/var/run/seatd.sock"
if [ -e "$SOCKET" ]; then
    echo "Removing old seatd socket..."
    rm -f "$SOCKET"
fi

echo "Starting SwayFX..."
seatd-launch sway