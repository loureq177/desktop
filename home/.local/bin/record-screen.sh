#!/usr/bin/env bash
# Screen recording toggle via wf-recorder with audio and notifications. Usage: [region|window|fullscreen]
set -euo pipefail

OUT_DIR="$HOME/Videos/Screencasts"
mkdir -p "$OUT_DIR"
RUN_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STATUS_FILE="$RUN_DIR/recording_status"
# Set only when this script is the one that enabled DND, so stopping never
# clears a DND the user turned on themselves.
DND_MARKER="$RUN_DIR/recording_dnd"

# Source centralized UI variables if available
UI_SH="${XDG_CONFIG_HOME:-$HOME/.config}/ui/ui.sh"
if [[ -f "$UI_SH" ]]; then
    # shellcheck source=/dev/null
    source "$UI_SH"
fi
# slurp styling: apply-ui exports SLURP_ARGS; the fallback matches it exactly.
SLURP_OPTS=(-d -b "#0d1117b0" -c "#58a6ff" -s "#58a6ff20" -w 2 -B "#00000000")
if [[ -v SLURP_ARGS[@] ]]; then
    SLURP_OPTS=("${SLURP_ARGS[@]}")
fi

LOCKFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/record_slurp.lock"
exec 200>"$LOCKFILE"
flock -n 200 || exit 0

play_sound() { canberra-gtk-play -i "$1" >/dev/null 2>&1 || true; }

HYPRPICKER_PID=""
cleanup() {
    [ -n "$HYPRPICKER_PID" ] && kill "$HYPRPICKER_PID" 2>/dev/null || true
}
trap cleanup EXIT

if pkill -INT -x wf-recorder; then
    if [ -f "$DND_MARKER" ]; then
        qs ipc call notifications dndOff || true
        rm -f "$DND_MARKER"
    fi

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
elif [ "$MODE" = "window" ]; then
    # Same as screenshot.sh window mode: record the active window as-is.
    GEOM=$(hyprctl activewindow -j 2>/dev/null | jq -r 'select(.at != null and .size != null) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null || true)
    if [[ -z "${GEOM:-}" || "$GEOM" == "null" ]]; then
        play_sound dialog-warning
        notify-send --app-name "Screen Record" "Screen Record" "No active window found."
        exit 0
    fi
    TARGET_ARGS=(-g "$GEOM")
else
    # Region mode mirrors screenshot.sh region mode: hover highlights only
    # the window under the cursor, click records it, drag records a region.
    WINDOW_RECTS=$(
        jq -r --argjson mons "$(hyprctl monitors -j 2>/dev/null || echo "[]")" '
          [ $mons[]? | (if .specialWorkspace.id != 0 then .specialWorkspace.id else .activeWorkspace.id end) ] as $ws |
          [ .[]? | select(.fullscreen != 0) | .workspace.id ] as $fs_ws |
          .[]? | select(
            .mapped and (.hidden | not) and
            (.workspace.id as $w | $ws | index($w)) and
            ((.workspace.id as $w | $fs_ws | index($w) | not) or .fullscreen != 0 or .floating)
          ) |
          "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
        ' <<< "$(hyprctl clients -j 2>/dev/null || echo "[]")" 2>/dev/null || true
    )

    hyprpicker -r -z &
    HYPRPICKER_PID=$!
    sleep 0.2
    if [[ -n "$WINDOW_RECTS" ]]; then
        GEOM=$(printf "%s\n" "$WINDOW_RECTS" | slurp "${SLURP_OPTS[@]}") || exit 0
    else
        GEOM=$(slurp "${SLURP_OPTS[@]}") || exit 0
    fi
    kill "$HYPRPICKER_PID" 2>/dev/null || true
    HYPRPICKER_PID=""

    if [[ -z "$GEOM" || "$GEOM" =~ [[:space:]]1x1$ ]]; then
        exit 0
    fi
    TARGET_ARGS=(-g "$GEOM")
fi

FILE="$OUT_DIR/$(date +'%Y-%m-%d_%H-%M-%S').mkv"
echo "$FILE" >"$STATUS_FILE"

exec 200>&-
if qs ipc call notifications status 2>/dev/null | grep -q '"dnd":true'; then
    : # already quiet; leave the user's DND alone
else
    qs ipc call notifications dndOn || true
    : >"$DND_MARKER"
fi
wf-recorder "${TARGET_ARGS[@]}" -f "$FILE" --audio=default &
disown

play_sound bell
