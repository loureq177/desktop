#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="$HOME/Videos/Screencasts"
mkdir -p "$OUT_DIR"
STATUS_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/recording_status"

LOCKFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/record_slurp.lock"
exec 200>"$LOCKFILE"
flock -n 200 || exit 0

if pkill -x wf-recorder; then
    swaync-client --dnd-off || true

    FILE=""
    if [[ -f "$STATUS_FILE" ]]; then
        FILE=$(cat "$STATUS_FILE")
        rm -f "$STATUS_FILE"
    fi

    pkill -RTMIN+2 waybar || true

    sleep 0.3

    if [[ -n "$FILE" && -f "$FILE" ]]; then
        notify-send --app-name "Screen Record" -t 5000 "Screen Record" -i "camera-video" "Recording saved to:\n$FILE"
    else
        notify-send --app-name "Screen Record" -t 5000 "Screen Record" -i "camera-video" "Recording stopped. No file found."
    fi
    exit 0
fi

MODE="${1:-region}"
TARGET_ARGS=()

if [ "$MODE" = "fullscreen" ] || [ "$MODE" = "full" ]; then
    FOCUSED_OUTPUT=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name' 2>/dev/null || true)
    if [[ -n "$FOCUSED_OUTPUT" ]]; then
        TARGET_ARGS=(-o "$FOCUSED_OUTPUT")
    fi
else
    GEOM=$(slurp -d -b "#00000080" -c "#ffffff" -w 2) || {
        exit 0
    }
    TARGET_ARGS=(-g "$GEOM")
fi

mkdir -p "$(dirname "$STATUS_FILE")"
FILE="$OUT_DIR/$(date +'%Y-%m-%d_%H-%M-%S').mkv"
echo "$FILE" >"$STATUS_FILE"

exec 200>&-
swaync-client --dnd-on || true
wf-recorder "${TARGET_ARGS[@]}" -f "$FILE" --audio=default &
disown
pkill -RTMIN+2 waybar || true

pw-play /usr/share/sounds/freedesktop/stereo/bell.oga &
