#!/bin/bash

paplay /usr/share/sounds/freedesktop/stereo/camera-shutter.oga --volume 65536
hyprshot --clipboard-only -z -m "$1"
