#!/bin/bash
# Waybar USB "Other..." button: pick a mounted USB drive, then eject it or open it

THEME="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/amber.rasi"

# "/dev/sdb1 [14.9G] -> /run/media/user/STICK" for every mounted removable partition
MENU_OPTIONS=$(lsblk -l -p -n -o NAME,RM,SIZE,MOUNTPOINT |
    awk '$2=="1" && $4!="" {name=$1; size=$3; $1=$2=$3=""; sub(/^ +/, ""); printf "%s [%s] -> %s\n", name, size, $0}')

[ -z "$MENU_OPTIONS" ] && exit 0

# -dmenu reads the choices from stdin, -i makes the search case-insensitive
CHOSEN=$(echo "$MENU_OPTIONS" | rofi -dmenu -i -p "Select:" -theme "$THEME")
[ -z "$CHOSEN" ] && exit 0

DEVICE=$(echo "$CHOSEN" | awk '{print $1}')
MOUNTPOINT=${CHOSEN#* -> }
# The whole drive (sdb for sdb1, mmcblk0 for mmcblk0p1), so it can be powered off
DRIVE="/dev/$(lsblk -no PKNAME "$DEVICE" | head -n1)"

WHAT_TO_DO=$'Eject USB\nOpen in CMD\nOpen in File Explorer\nExit'
CHOSEN_SECOND=$(echo "$WHAT_TO_DO" | rofi -dmenu -p "What to do?" -theme "$THEME")

case "$CHOSEN_SECOND" in
    "Eject USB")
        if ! findmnt "$DEVICE" > /dev/null; then
            notify-send "USB Already Unmounted" "Powering off $DEVICE..." -i media-removable -h string:bgcolor:#555555
            # Power it off anyway in case the light is still on
            udisksctl power-off -b "$DRIVE" 2>/dev/null
            exit 0
        fi
        if udisksctl unmount -b "$DEVICE"; then
            # Power off the drive entirely so the LED turns off and it's 100% safe to pull
            udisksctl power-off -b "$DRIVE" 2>/dev/null
            notify-send "USB Ejected" "$DEVICE has been safely removed." -i media-removable -h string:bgcolor:#ff6600
        else
            notify-send "USB Eject Error" "Failed to unmount $DEVICE. It might be in use." -i media-removable -u critical -h string:bgcolor:#ff6600
        fi
        ;;
    "Open in CMD")
        kitty -d "$MOUNTPOINT"
        ;;
    "Open in File Explorer")
        nautilus "$MOUNTPOINT"
        ;;
esac
