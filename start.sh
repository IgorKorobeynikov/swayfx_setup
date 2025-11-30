#!/bin/sh
mkdir -p ~/bin

cat > ~/bin/start-swayfx << 'EOF'
#!/bin/sh
export XDG_RUNTIME_DIR=/var/run/user/$(id -u)
[ -d "$XDG_RUNTIME_DIR" ] || { mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"; }
exec dbus-run-session swayfx
EOF

chmod +x ~/bin/start-swayfx
