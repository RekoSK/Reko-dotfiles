#!/bin/bash

NAME=$(cat "/tmp/waybarusb$1.txt" | xargs)
USBPATH=$(lsblk -nlpo LABEL,NAME | awk -v target="$NAME" '$1 == target {printf "%s", $2}')

udisksctl mount -b "$USBPATH"
MOUNTPOINT=$(lsblk -nlpo LABEL,MOUNTPOINT | awk -v target="$NAME" '$1 == target {printf "%s", $2}')
notify-send "USB Mounted" "Mounted in: $MOUNTPOINT" -i media-removable -h string:bgcolor:#555555