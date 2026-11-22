#!/bin/bash

GOTO_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/goto"

MENU_OPTIONS=$(awk -F/ '{print "[ "$NF" ] "$0}' "$GOTO_DIR/menu_options.txt")

if [ "$1" == "kitty" ]; then
    PICKED_OPTION=$(echo "$MENU_OPTIONS" | rofi -dmenu -p "Places - Terminal" -theme "$GOTO_DIR/goto.rasi")
else
    PICKED_OPTION=$(echo "$MENU_OPTIONS" | rofi -dmenu -p "Places" -theme "$GOTO_DIR/goto.rasi")
fi

if [ -z "$PICKED_OPTION" ]; then
    exit 0
fi

# Entries look like "[ Downloads ] /home/me/Downloads"; a typed-in path is used as it is
LOCATION=$(realpath -e -- "${PICKED_OPTION#\[ *\] }" 2>/dev/null)

if [ ! -d "$LOCATION" ]; then
    notify-send "Places" "Not a folder: $PICKED_OPTION"
    exit 1
fi

# Remember new places (exact match, so /home/me/Doc doesn't count as /home/me/Documents)
if ! grep -qxF "$LOCATION" "$GOTO_DIR/menu_options.txt"; then
    echo "$LOCATION" >> "$GOTO_DIR/menu_options.txt"
fi

if [ "$1" == "kitty" ]; then
    echo "$LOCATION"
    kitty -d "$LOCATION" &
else
    nautilus "$LOCATION" &
fi