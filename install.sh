#!/bin/sh

set -eu

log() {
  echo "$@"
}

warn() {
  echo "WARNING: $*" >&2
}

WALLPAPER_URL="https://raw.githubusercontent.com/smravec/.dotfiles-swayfx/main/sway/wallpaper.png"

REQUIRED_PACKAGES="
  swayfx
  alacritty
  foot
  wofi
  eww-wayland
  dunst
  swaylock-effects
  swayidle
  grim
  slurp
  wl-clipboard
  noto-basic
"
REQUIRED_GROUPS="video seatd"
RC_CONF="/etc/rc.conf"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

require_root() {
  if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root (use doas or sudo)." >&2
    exit 1
  fi
}

check_freebsd_version() {
  os=$(uname -s 2>/dev/null || echo "")
  ver=$(freebsd-version -u 2>/dev/null || uname -r 2>/dev/null || echo "")
  case "$os" in
    FreeBSD) ;;
    *)
      echo "Unsupported OS: $os. FreeBSD 14.x required." >&2
      exit 1
      ;;
  esac
  case "$ver" in
    14.*) ;;
    *)
      echo "FreeBSD 14.x required (detected $ver)." >&2
      exit 1
      ;;
  esac
}

detect_user() {
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    echo "$SUDO_USER"
    return
  fi
  if command -v logname >/dev/null 2>&1; then
    user=$(logname 2>/dev/null || true)
    if [ -n "$user" ] && [ "$user" != "root" ]; then
      echo "$user"
      return
    fi
  fi
  echo "$(id -un)"
}

user_home() {
  user="$1"
  if command -v getent >/dev/null 2>&1; then
    home=$(getent passwd "$user" | cut -d: -f6)
  else
    home=$(awk -F: -v u="$user" '$1==u {print $6}' /etc/passwd)
  fi
  if [ -z "$home" ]; then
    echo "Could not determine home directory for $user" >&2
    exit 1
  fi
  echo "$home"
}

ensure_pkg() {
  if ! command -v pkg >/dev/null 2>&1; then
    echo "pkg is not available; cannot continue." >&2
    exit 1
  fi
}

force_latest_pkg_repo() {
  mkdir -p /usr/local/etc/pkg/repos
  cat >/usr/local/etc/pkg/repos/FreeBSD.conf <<'EOF'
FreeBSD: {
  url: "pkg+https://pkg.FreeBSD.org/${ABI}/latest",
  mirror_type: "srv",
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg",
  enabled: yes
}
EOF
  pkg update -f
}

install_packages() {
  echo "Installing packages..."
  force_latest_pkg_repo
  pkg install -y $REQUIRED_PACKAGES seatd dbus
}

ensure_groups() {
  for grp in $REQUIRED_GROUPS; do
    if ! pw group show "$grp" >/dev/null 2>&1; then
      pw groupadd "$grp"
    fi
  done
}

add_user_to_groups() {
  user="$1"
  current_groups=$(id -Gn "$user" 2>/dev/null | tr ' ' ',')
  new_groups=""
  for grp in $REQUIRED_GROUPS; do
    case ",$current_groups," in
      *,"$grp",*) ;;
      *) new_groups="${new_groups:+$new_groups,}$grp" ;;
    esac
  done
  if [ -n "$new_groups" ]; then
    combined_groups=$current_groups
    if [ -n "$combined_groups" ]; then
      combined_groups="$combined_groups,$new_groups"
    else
      combined_groups="$new_groups"
    fi
    pw usermod "$user" -G "$combined_groups"
  fi
}

set_rc_conf() {
  if command -v sysrc >/dev/null 2>&1; then
    sysrc -f "$RC_CONF" dbus_enable=YES >/dev/null
    sysrc -f "$RC_CONF" seatd_enable=YES >/dev/null
  else
    if ! grep -q '^dbus_enable=' "$RC_CONF" 2>/dev/null; then
      echo 'dbus_enable="YES"' >>"$RC_CONF"
    fi
    if ! grep -q '^seatd_enable=' "$RC_CONF" 2>/dev/null; then
      echo 'seatd_enable="YES"' >>"$RC_CONF"
    fi
  fi
}

deploy_configs() {
  user="$1"
  home_dir="$2"
  target_config="$home_dir/.config"
  src_root="$SCRIPT_DIR/configs"
  ts=$(date +%Y%m%d%H%M%S)
  user_group=$(id -gn "$user" 2>/dev/null || true)
  TARGET_USER="$user"
  TARGET_GROUP="$user_group"

  mkdir -p "$target_config"
  for src in "$src_root"/*; do
    [ -e "$src" ] || continue
    name=$(basename "$src")
    [ "$name" = "alacritty" ] && continue
    dest="$target_config/$name"
    if [ -e "$dest" ]; then
      mv "$dest" "${dest}.bak.$ts"
    fi
    cp -R "$src" "$dest"
    if [ -n "$TARGET_GROUP" ]; then
      chown -R "$TARGET_USER":"$TARGET_GROUP" "$dest"
    else
      chown -R "$TARGET_USER" "$dest"
    fi
  done

  alacritty_src="$src_root/alacritty"
  if [ -d "$alacritty_src" ]; then
    alacritty_dest="$target_config/alacritty"
    if [ -e "$alacritty_dest" ]; then
      mv "$alacritty_dest" "${alacritty_dest}.bak.$ts"
    fi
    mkdir -p "$alacritty_dest"
    cp -R "$alacritty_src"/. "$alacritty_dest"
    if [ -n "$TARGET_GROUP" ]; then
      chown -R "$TARGET_USER":"$TARGET_GROUP" "$alacritty_dest"
    else
      chown -R "$TARGET_USER" "$alacritty_dest"
    fi
  fi
}

install_wallpaper() {
  dest="$TARGET_HOME/.config/sway/wallpaper.png"
  dest_dir=$(dirname "$dest")

  if [ -f "$dest" ]; then
    log "Wallpaper already exists at $dest; skipping download."
    return
  fi

  mkdir -p "$dest_dir"

  if command -v fetch >/dev/null 2>&1; then
    if ! fetch -o "$dest" "$WALLPAPER_URL"; then
      warn "Failed to download wallpaper via fetch from $WALLPAPER_URL"
      return
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -O "$dest" "$WALLPAPER_URL"; then
      warn "Failed to download wallpaper via wget from $WALLPAPER_URL"
      return
    fi
  elif command -v curl >/dev/null 2>&1; then
    if ! curl -L -o "$dest" "$WALLPAPER_URL"; then
      warn "Failed to download wallpaper via curl from $WALLPAPER_URL"
      return
    fi
  else
    warn "No fetch, wget, or curl available to download wallpaper."
    return
  fi

  if [ -n "${TARGET_GROUP:-}" ]; then
    chown "$TARGET_USER":"$TARGET_GROUP" "$dest"
  else
    chown "$TARGET_USER" "$dest"
  fi
}

main() {
  require_root
  check_freebsd_version
  ensure_pkg

  target_user=$(detect_user)
  home_dir=$(user_home "$target_user")
  TARGET_USER="$target_user"
  TARGET_HOME="$home_dir"
  TARGET_GROUP=$(id -gn "$target_user" 2>/dev/null || true)

  install_packages
  ensure_groups
  add_user_to_groups "$target_user"
  set_rc_conf
  deploy_configs "$target_user" "$home_dir"
  install_wallpaper

  cat <<'EOF'
Setup complete.
Start a session with:
  dbus-run-session sway
EOF
}

main "$@"
