#!/bin/bash
PROCESS=$(pgrep -l keepassxc | awk '$2=="keepassxc" {print $2}')

if [ -z "$PROCESS" ]; then
    keepassxc &
    sleep 1
    CHECK=$(hyprctl clients | grep "class: org.keepassxc.KeePassXC")
    # Wait until the KeePassXC window is closed again (the database is unlocked)
    while [[ -n $CHECK ]]; do
        sleep 0.5
        CHECK=$(hyprctl clients | grep "class: org.keepassxc.KeePassXC")
    done
fi

brave-origin &