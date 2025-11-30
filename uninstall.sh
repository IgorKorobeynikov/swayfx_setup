#!/bin/sh

# Plan: remove installed packages, undo rc.conf changes, and restore configs if backups exist.

set -e

# TODO: pkg delete swayfx swayidle swaylock-effects foot wofi eww dunst grim slurp wl-clipboard noto-basic seatd dbus.
# TODO: remove dbus_enable/seatd_enable entries from /etc/rc.conf if added by install.
# TODO: optionally drop user from video/seatd groups.
# TODO: restore backed up ~/.config items or clean up deployed configs.
