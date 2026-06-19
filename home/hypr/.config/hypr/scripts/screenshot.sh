#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"

pkill -x slurp && {
    exit 0
}

FILE="$DIR/$(date +'%Y-%m-%d_%H-%M-%S').png"

if [ "$MODE" = "region" ]; then
    hyprpicker -r -z &
    PICKER_PID=$!
    sleep 0.1

    GEOM=$(slurp -d -b "#00000080" -c "#ffffff" -w 2) || {
        kill "$PICKER_PID" 2>/dev/null || true
        exit 0
    }

    grim -g "$GEOM" - | tee "$FILE" | wl-copy
    kill "$PICKER_PID" 2>/dev/null || true
else
    grim - | tee "$FILE" | wl-copy
fi

notify-send -t 3000 -a "Screenshot" -i "$FILE" "Image saved and copied to clipboard." "$FILE"
