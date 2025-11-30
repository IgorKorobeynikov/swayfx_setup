#!/bin/sh

set -eu

fail() {
  echo "Smoke failure: $*" >&2
  exit 1
}

for bin in sway foot eww wofi; do
  command -v "$bin" >/dev/null 2>&1 || fail "missing binary: $bin"
done

HOME_DIR=${HOME:-$(getent passwd "$(id -un)" | cut -d: -f6 2>/dev/null)}
[ -n "$HOME_DIR" ] || HOME_DIR="$(awk -F: -v u="$(id -un)" '$1==u {print $6}' /etc/passwd)"
[ -n "$HOME_DIR" ] || fail "cannot determine HOME"

[ -f "$HOME_DIR/.config/sway/config" ] || fail "missing sway config: $HOME_DIR/.config/sway/config"
[ -d "$HOME_DIR/.config/eww" ] || fail "missing eww directory: $HOME_DIR/.config/eww"

echo "Smoke OK"
exit 0
