#!/bin/bash

NAME=$(cat "/tmp/waybarusb$1.txt" | xargs)
USBPATH=$(lsblk -nlpo LABEL,NAME | awk -v target="$NAME" '$1 == target {printf "%s", $2}')
# The whole drive (sdb for sdb1, mmcblk0 for mmcblk0p1), so it can be powered off
DRIVE="/dev/$(lsblk -no PKNAME "$USBPATH" | head -n1)"

if ! findmnt "$USBPATH" > /dev/null; then
    notify-send "USB Already Unmounted" "Powering off $USBPATH..." -i media-removable -h string:bgcolor:#555555
    
    # Optional: Try to power off anyway just in case the light is still on
    udisksctl power-off -b "$DRIVE" 2>/dev/null
    exit 0
fi
if udisksctl unmount -b "$USBPATH"; then
    # Power off the drive entirely so the LED turns off and it's 100% safe to pull
    udisksctl power-off -b "$DRIVE" 2>/dev/null
    
    # Send a notification using your Lava orange color!
    notify-send "USB Ejected" "$USBPATH has been safely removed." -i media-removable -h string:bgcolor:#ff6600
else
    notify-send "USB Eject Error" "Failed to unmount $USBPATH. It might be in use." -u critical -i media-removable -h string:bgcolor:#ff6600
fi