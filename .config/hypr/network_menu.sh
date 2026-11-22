#!/bin/bash
# Waybar network button: opens the ronema network menu, or says why it can't

notify() { notify-send -a "Network" "Network menu" "$1"; }

if ! command -v nmcli >/dev/null 2>&1; then
    notify "Needs NetworkManager. Install it with: sudo pacman -S networkmanager"
elif ! systemctl is-active -q NetworkManager; then
    notify "NetworkManager isn't running. Start it with: sudo systemctl enable --now NetworkManager"
else
    exec sh "${XDG_CONFIG_HOME:-$HOME/.config}/ronema/ronema"
fi
