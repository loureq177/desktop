#!/bin/bash
item=$(cliphist list | rofi -dmenu -p 'Clipboard' -display-columns 2) || exit 1
echo "$item" | cliphist decode | wl-copy
wtype -M ctrl V -m ctrl
