#!/usr/bin/env bash
# Screenshots via grim/slurp/hyprpicker with Satty editor integration. Usage: [region|window|output]
set -euo pipefail

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
    SLURP_OPTS=(-d -b "#0d1117b0" -c "#58a6ff" -s "#58a6ff20" -w 2 -B "#00000000")
fi

LOCKFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/screenshot_slurp.lock"
exec 200>"$LOCKFILE"
flock -n 200 || exit 0

play_sound() { canberra-gtk-play -i "$1" >/dev/null 2>&1 || true; }

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/$(date +'%Y-%m-%d_%H-%M-%S').png"

HYPRPICKER_PID=""
cleanup() {
    [ -n "$HYPRPICKER_PID" ] && kill "$HYPRPICKER_PID" 2>/dev/null || true
}
trap cleanup EXIT

if [ "${1:-region}" = "region" ]; then
    # Only offer windows that are actually visible: when a special workspace
    # is open on a monitor it covers the regular workspace, so the regular
    # workspace windows would otherwise be selectable yet invisible.
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

    grim -g "$GEOM" "$FILE"
elif [ "${1:-}" = "window" ]; then
    GEOM=$(hyprctl activewindow -j 2>/dev/null | jq -r 'select(.at != null and .size != null) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null || true)
    if [[ -z "${GEOM:-}" || "$GEOM" == "null" ]]; then
        play_sound dialog-warning
        notify-send --app-name "Screenshot" "Screenshot" "No active window found."
        exit 0
    fi
    grim -g "$GEOM" "$FILE"
else
    FOCUSED_OUTPUT=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null || true)
    grim -o "$FOCUSED_OUTPUT" "$FILE"
fi

if [ ! -f "$FILE" ]; then
    exit 0
fi

play_sound camera-shutter

exec 200>&-
wl-copy -t image/png <"$FILE"

ACTION=$(notify-send --app-name "Screenshot" -t 5000 "Screenshot" -i "$FILE" -A "default=Edit" -A "edit=Edit with Satty" "Screenshot saved and copied to clipboard.")

if [ "$ACTION" = "default" ] || [ "$ACTION" = "edit" ]; then
    satty --filename "$FILE" --fullscreen --output-filename "$FILE"
fi
