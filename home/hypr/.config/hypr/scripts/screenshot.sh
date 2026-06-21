#!/usr/bin/env bash
set -euo pipefail

LOCKFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/screenshot_slurp.lock"
if [ -f "$LOCKFILE" ] && kill -0 "$(cat "$LOCKFILE")" 2>/dev/null; then
    exit 0
fi
echo $$ >"$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/$(date +'%Y-%m-%d_%H-%M-%S').png"

if [ "${1:-region}" = "region" ]; then
    GEOM=$(slurp -d -b "#00000080" -c "#ffffff" -w 2) || exit 0
    grim -g "$GEOM" "$FILE"
else
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required for fullscreen screenshots. Install it with: paru -S jq" >&2
        exit 1
    fi
    FOCUSED_OUTPUT=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
    grim -o "$FOCUSED_OUTPUT" "$FILE"
fi

if [ ! -f "$FILE" ]; then
    exit 0
fi

wl-copy <"$FILE"

ACTION=$(notify-send "Screenshot" -i "$FILE" -A "default=Edit" -A "edit=Edit with Satty" "Screenshot saved and copied to clipboard.")

if [ "$ACTION" = "default" ] || [ "$ACTION" = "edit" ]; then
    satty --filename "$FILE" --fullscreen --output-filename "$FILE"
fi
