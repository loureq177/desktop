# shellcheck shell=bash
# Shared helpers for screenshot, record-screen and ocr. Source, don't execute.

source "${XDG_CONFIG_HOME:-$HOME/.config}/ui/ui.sh"  # SLURP_ARGS

play_sound() { canberra-gtk-play -i "$1" >/dev/null 2>&1 || true; }

# Allow one instance per lock name; the lock lives on fd 200 until `exec 200>&-`.
single_instance() {
    exec 200>"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$1.lock"
    flock -n 200 || exit 0
}

HYPRPICKER_PID=""
stop_picker() {
    [[ -z "$HYPRPICKER_PID" ]] || kill "$HYPRPICKER_PID" 2>/dev/null || true
    HYPRPICKER_PID=""
}

# Visible windows as slurp rects, skipping those hidden behind a fullscreen one.
window_rects() {
    jq -r --argjson mons "$(timeout 5 hyprctl monitors -j 2>/dev/null || echo "[]")" '
      [ $mons[]? | (if .specialWorkspace.id != 0 then .specialWorkspace.id else .activeWorkspace.id end) ] as $ws |
      [ .[]? | select(.fullscreen != 0) | .workspace.id ] as $fs_ws |
      .[]? | select(
        .mapped and (.hidden | not) and
        (.workspace.id as $w | $ws | index($w)) and
        ((.workspace.id as $w | $fs_ws | index($w) | not) or .fullscreen != 0 or .floating)
      ) |
      "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
    ' <<<"$(timeout 5 hyprctl clients -j 2>/dev/null || echo "[]")" 2>/dev/null || true
}

# pick_region [--freeze] [--windows]: select an area with slurp into $GEOM.
# --freeze freezes the screen while selecting, --windows offers window rects.
# Returns 1 when the selection is cancelled.
# shellcheck disable=SC2034  # GEOM is read by the sourcing script
pick_region() {
    local arg freeze=false rects=""
    for arg in "$@"; do
        case "$arg" in
        --freeze) freeze=true ;;
        --windows) rects="$(window_rects)" ;;
        esac
    done
    if $freeze; then
        hyprpicker -r -z &
        HYPRPICKER_PID=$!
        sleep 0.2
    fi
    if [[ -n "$rects" ]]; then
        GEOM=$(printf "%s\n" "$rects" | slurp "${SLURP_ARGS[@]}") || { stop_picker; return 1; }
    else
        GEOM=$(slurp "${SLURP_ARGS[@]}") || { stop_picker; return 1; }
    fi
    stop_picker
}

is_click() { [[ -z "$1" || "$1" =~ [[:space:]]1x1$ ]]; }

active_window_geom() {
    timeout 5 hyprctl activewindow -j 2>/dev/null |
        jq -r 'select(.at != null and .size != null) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null || true
}

focused_output() {
    timeout 5 hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null || true
}
