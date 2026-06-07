#!/usr/bin/env bash

MODE="$1"
DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/$(date +'%Y-%m-%d_%H-%M-%S').png"

if [ "$MODE" = "region" ]; then
    grimblast --freeze copysave area "$FILE"
else
    grimblast copysave output "$FILE"
fi

if [ ! -f "$FILE" ]; then
    exit 0
fi

ACTION=$(notify-send -t 5000 -a "Screenshot" -i "$FILE" -A "default=Edit" -A "edit=Edit with Satty" "Screenshot saved." "Copied to clipboard. Click to edit.")

if [ "$ACTION" = "default" ] || [ "$ACTION" = "edit" ]; then
    satty --filename "$FILE" --fullscreen --output-filename "$FILE"
fi
