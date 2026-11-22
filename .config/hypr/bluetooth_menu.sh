#!/bin/bash
# Waybar bluetooth button: opens rofi-bluetooth, or says why it can't

notify() { notify-send -a "Bluetooth" "Bluetooth" "$1"; }

if ! command -v rofi-bluetooth >/dev/null 2>&1; then
    notify "rofi-bluetooth isn't installed. Run the dotfiles installer with rofi-bluetooth ticked."
elif ! systemctl is-active -q bluetooth; then
    notify "The bluetooth service isn't running. Start it with: sudo systemctl enable --now bluetooth"
# bluetoothctl waits forever when it can't reach the service, hence the timeout
elif ! timeout 3 bluetoothctl list 2>/dev/null | grep -q '^Controller'; then
    notify "No bluetooth adapter found on this computer."
else
    exec rofi-bluetooth -theme "${XDG_CONFIG_HOME:-$HOME/.config}/rofi-bluetooth/reko.rasi" -p "󰂯"
fi
