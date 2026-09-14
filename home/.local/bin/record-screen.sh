#!/usr/bin/env bash
# Screen recording toggle via wf-recorder with audio and notifications. Usage: [region|fullscreen]
set -euo pipefail

OUT_DIR="$HOME/Videos/Screencasts"
mkdir -p "$OUT_DIR"
STATUS_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/recording_status"

# Source centralized UI variables if available
UI_SH="${XDG_CONFIG_HOME:-$HOME/.config}/ui/ui.sh"
if [[ -f "$UI_SH" ]]; then
    # shellcheck source=/dev/null
    source "$UI_SH"
fi
if [[ -v SLURP_ARGS[@] ]]; then
    SLURP_OPTS=("${SLURP_ARGS[@]}")
elif [[ -n "${SLURP_OPTS:-}" ]]; then
    # shellcheck disable=SC2206
    SLURP_OPTS=($SLURP_OPTS)
else
    SLURP_OPTS=(-d -b "#0d1117b0" -c "#58a6ff" -s "#58a6ff20" -w 2)
fi

LOCKFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/record_slurp.lock"
exec 200>"$LOCKFILE"
flock -n 200 || exit 0

play_sound() { canberra-gtk-play -i "$1" >/dev/null 2>&1 || true; }

if pkill -INT -x wf-recorder; then
    qs ipc call notifications dndOff || true

    FILE=""
    if [[ -f "$STATUS_FILE" ]]; then
        FILE=$(<"$STATUS_FILE")
        rm -f "$STATUS_FILE"
    fi

    # Wait for wf-recorder to actually exit before the bar re-polls pgrep.
    # Otherwise the bar re-runs pgrep while the recorder is still finalizing
    # and keeps showing the red dot forever.
    for _ in $(seq 1 50); do
        pgrep -x wf-recorder >/dev/null || break
        sleep 0.1
    done


    # Release lock before waiting for notification action
    exec 200>&-

    if [[ -n "$FILE" && -f "$FILE" ]]; then
        play_sound complete
        ACTION=$(notify-send \
            --app-name "Screen Record" \
            -t 8000 \
            -i "camera-video" \
            -A "default=Play" \
            -A "open=Open in Video Player" \
            "Screen Record" \
            "Recording saved to:\n$FILE" 2>/dev/null || true)

        if [[ "$ACTION" == "default" || "$ACTION" == "open" ]]; then
            if command -v showtime >/dev/null 2>&1; then
                showtime "$FILE" >/dev/null 2>&1 &
            else
                xdg-open "$FILE" >/dev/null 2>&1 &
            fi
            disown
        fi
    else
        play_sound dialog-warning
        notify-send --app-name "Screen Record" -t 5000 "Screen Record" -i "camera-video" "Recording stopped. No file found."
    fi
    exit 0
fi

MODE="${1:-region}"
TARGET_ARGS=()

if [ "$MODE" = "fullscreen" ] || [ "$MODE" = "full" ]; then
    FOCUSED_OUTPUT=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null || true)
    if [[ -n "$FOCUSED_OUTPUT" ]]; then
        TARGET_ARGS=(-o "$FOCUSED_OUTPUT")
    fi
else
    GEOM=$(slurp "${SLURP_OPTS[@]}") || {
        exit 0
    }
    TARGET_ARGS=(-g "$GEOM")
fi

FILE="$OUT_DIR/$(date +'%Y-%m-%d_%H-%M-%S').mkv"
echo "$FILE" >"$STATUS_FILE"

exec 200>&-
qs ipc call notifications dndOn || true
wf-recorder "${TARGET_ARGS[@]}" -f "$FILE" --audio=default &
disown

play_sound bell
