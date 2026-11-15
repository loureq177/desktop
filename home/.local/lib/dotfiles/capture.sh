# shellcheck shell=bash
# Shared helpers for screenshot, record-screen and ocr. Source, don't execute.

source "${XDG_CONFIG_HOME:-$HOME/.config}/ui/ui.sh"  # SLURP_ARGS

# In the background: canberra-gtk-play lasts as long as the sound, and the
# notification should not wait for it. Off the lock, which it would hold.
play_sound() { canberra-gtk-play -i "$1" >/dev/null 2>&1 200>&- & disown; }

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
      [ $mons[]? | (if .specialWorkspace.name != "" then .specialWorkspace.name else .activeWorkspace.name end) ] as $ws |
      [ .[]? | select(.fullscreen != 0) | .workspace.name ] as $fs_ws |
      .[]? | select(
        .mapped and (.hidden | not) and
        (.workspace.name as $w | $ws | index($w)) and
        ((.workspace.name as $w | $fs_ws | index($w) | not) or .fullscreen != 0 or .floating)
      ) |
      "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
    ' <<<"$(timeout 5 hyprctl clients -j 2>/dev/null || echo "[]")" 2>/dev/null || true
}

# Every monitor as a slurp rect, in logical pixels as slurp counts them.
output_rects() {
    timeout 5 hyprctl monitors -j 2>/dev/null | jq -r '
      .[]? | (if .transform % 2 == 1 then [.height, .width] else [.width, .height] end) as $s |
      "\(.x),\(.y) \($s[0] / .scale | floor)x\($s[1] / .scale | floor)"
    ' 2>/dev/null || true
}

# What moves the windows while slurp is up: a workspace or special shown, a window
# opened, closed, moved, floated or made fullscreen (Hyprland's socket2 events).
_LAYOUT_EVENTS='^(workspace|activespecial|openwindow|closewindow|movewindow|changefloatingmode|fullscreen)>>'

# _restart_on_layout PID FLAG: kills slurp's PID at the first of them, FLAG made first.
_restart_on_layout() {
    local sock="${XDG_RUNTIME_DIR:-}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock" line
    [[ -S "$sock" ]] || return 0
    exec < <(exec socat -u "UNIX-CONNECT:$sock" - 2>/dev/null)
    while IFS= read -r line; do
        [[ "$line" =~ $_LAYOUT_EVENTS ]] || continue
        : >"$2"
        kill "$1" 2>/dev/null
        break
    done
    kill $! 2>/dev/null
}

# pick_region [--freeze] [--windows] [--outputs]: an area from slurp into $GEOM;
# returns 1 when cancelled. slurp starts again, with the windows where they are now,
# when they move under it.
# shellcheck disable=SC2034  # GEOM is read by the sourcing script
pick_region() {
    local arg freeze=false windows=false outputs=false rects out slurp watch="" rc
    for arg in "$@"; do
        case "$arg" in
        --freeze) freeze=true ;;
        --windows) windows=true ;;
        --outputs) outputs=true ;;
        esac
    done
    out=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/pick_region.XXXXXX")
    while :; do
        rects=""
        ! $windows || rects+="$(window_rects)"$'\n'
        ! $outputs || rects+="$(output_rects)"$'\n'
        rects="$(sed '/^$/d' <<<"$rects")"
        if $freeze; then
            hyprpicker -r -z 200>&- &
            HYPRPICKER_PID=$!
            sleep 0.2
        fi
        if [[ -n "$rects" ]]; then
            slurp "${SLURP_ARGS[@]}" <<<"$rects" >"$out" 200>&- &
        else
            slurp "${SLURP_ARGS[@]}" >"$out" 200>&- &
        fi
        slurp=$!
        if $windows; then
            _restart_on_layout "$slurp" "$out.moved" 200>&- &
            watch=$!
        fi
        rc=0
        wait "$slurp" || rc=$?
        if [[ -n "$watch" ]]; then
            pkill -P "$watch" 2>/dev/null || true
            kill "$watch" 2>/dev/null || true
            wait "$watch" 2>/dev/null || true
        fi
        stop_picker
        [[ -e "$out.moved" ]] || break
        rm -f -- "$out.moved"
        # A slurp done just before the kill keeps its pick.
        ((rc == 143)) || break
        # The frozen frame waits for the workspace's slide (look.lua) to end.
        ! $freeze || sleep 0.45
    done
    GEOM=$(<"$out")
    rm -f -- "$out"
    ((rc == 0))
}

is_click() { [[ -z "$1" || "$1" =~ [[:space:]]1x1$ ]]; }

focused_output() {
    timeout 5 hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null || true
}
