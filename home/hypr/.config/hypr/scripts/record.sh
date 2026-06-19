#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="$HOME/Videos/Screencasts"
mkdir -p "$OUT_DIR"

pkill -x slurp && {
    exit 0
}

if pkill -x wf-recorder; then
    sleep 0.5
    FILE=$(ls -t "$OUT_DIR"/recording_*.mkv 2>/dev/null | head -1 || true)

    if [[ -f "$FILE" ]]; then
        notify-send -t 3000 -a "Screen Record" -i "$FILE" "Recording saved." "$FILE"
    else
        notify-send -t 3000 -a "Screen Record" "Recording stopped." "No file found."
    fi
    exit 0
fi

GEOM=$(slurp -d -b "#00000080" -c "#ffffff" -w 2) || {
    exit 0
}

FILE="$OUT_DIR/recording_$(date +'%Y-%m-%d_%H-%M-%S').mkv"

wf-recorder -g "$GEOM" -f "$FILE" -a --audio=default &

notify-send -t 3000 -a "Screen Record" "Recording started." "Press SUPER+CTRL+R to stop."
