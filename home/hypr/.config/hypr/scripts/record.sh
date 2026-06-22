#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="$HOME/Videos/Screencasts"
mkdir -p "$OUT_DIR"
STATUS_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/recording_status"

LOCKFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/record_slurp.lock"
if [ -f "$LOCKFILE" ] && kill -0 "$(cat "$LOCKFILE")" 2>/dev/null; then
    exit 0
fi

if pkill -x wf-recorder; then
    FILE=""
    if [[ -f "$STATUS_FILE" ]]; then
        FILE=$(cat "$STATUS_FILE")
        rm -f "$STATUS_FILE"
    fi

    sleep 0.3

    if [[ -f "$FILE" ]]; then
        notify-send --app-name "Screen Record" -t 5000 "Screen Record" -i "camera-video" "Recording saved to:\n$FILE"
    else
        notify-send --app-name "Screen Record" -t 5000 "Screen Record" -i "camera-video" "Recording stopped. No file found."
    fi
    exit 0
fi

GEOM=$(slurp -d -b "#00000080" -c "#ffffff" -w 2) || {
    rm -f "$LOCKFILE"
    exit 0
}
echo $$ >"$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

mkdir -p "$(dirname "$STATUS_FILE")"
FILE="$OUT_DIR/$(date +'%Y-%m-%d_%H-%M-%S').mkv"
echo "$FILE" >"$STATUS_FILE"

wf-recorder -g "$GEOM" -f "$FILE" -a --audio=default &
