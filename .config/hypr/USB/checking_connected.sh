#!/bin/bash

CONNECTED_USBS=$(lsblk -nlo LABEL,RM | awk '$1!="" && $2=="1" {print $1}')

if [ -z "$CONNECTED_USBS" ]; then
    echo "{\"text\": \"\", \"class:\": \"invisible\"}"
    exit 0
fi

if [ "$1" != "4" ]; then
    NAME=$(sed -n "${1}p" <<< "$CONNECTED_USBS")
    if [ -z "$NAME" ]; then
        echo "{\"text\": \"\", \"class:\": \"invisible\"}"
        exit 0
    fi
    echo "$NAME" > "/tmp/waybarusb$1.txt"
    echo "{\"text\": \" $NAME\", \"class\": \"visible_usb\"}"
else
    NUM_OF_CONNECTED=$(grep -c '^' <<< "$CONNECTED_USBS")
    if [ "$NUM_OF_CONNECTED" -le 3 ]; then
        echo "{\"text\": \"\", \"class:\": \"invisible\"}"
        exit 0
    fi
    echo "{\"text\": \"󱇰 Other...\", \"class\": \"visible_usb\"}"
fi