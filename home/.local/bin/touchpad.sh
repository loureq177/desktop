#!/usr/bin/env bash
# Touchpad on/off toggle with the quickshell OSD. Usage: [toggle|on|off|status]
# Runtime device changes go through `hyprctl eval': `hyprctl keyword' is a
# no-op with the Lua config provider (see `man hyprctl').
set -euo pipefail

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/touchpad"
STATE_FILE="$STATE_DIR/enabled" # 1 = on, 0 = off; absent means on
ACTION="${1:-toggle}"
case "$ACTION" in
toggle | on | off | status) ;;
*) echo "touchpad.sh: want toggle|on|off|status" >&2; exit 2 ;;
esac

command -v hyprctl >/dev/null 2>&1 || { echo "touchpad.sh: hyprctl not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "touchpad.sh: jq not found" >&2; exit 1; }

devices_json="$(hyprctl devices -j 2>/dev/null)" || {
    echo "touchpad.sh: hyprctl devices failed" >&2
    exit 1
}
mapfile -t DEVICES < <(jq -r '.mice[]? | select(.name | test("touchpad"; "i")) | .name' <<<"$devices_json")
if ((${#DEVICES[@]} == 0)); then
    echo "touchpad.sh: no touchpad device found" >&2
    exit 1
fi

current=1
if [[ -f "$STATE_FILE" ]]; then
    current="$(<"$STATE_FILE")"
fi
if [[ "$current" != 0 && "$current" != 1 ]]; then
    current=1
fi

if [[ "$ACTION" == status ]]; then
    if [[ "$current" == 1 ]]; then echo "on"; else echo "off"; fi
    exit 0
fi

target=1
if [[ "$ACTION" == toggle ]]; then
    if [[ "$current" == 1 ]]; then target=0; else target=1; fi
elif [[ "$ACTION" == off ]]; then
    target=0
fi

lua_bool=false
if [[ "$target" == 1 ]]; then lua_bool=true; fi
for dev in "${DEVICES[@]}"; do
    esc="${dev//\\/\\\\}"
    esc="${esc//\"/\\\"}"
    out="$(hyprctl eval "hl.device({ name = \"$esc\", enabled = $lua_bool })" 2>&1)" || {
        echo "touchpad.sh: failed for '$dev': $out" >&2
        exit 1
    }
done

mkdir -p "$STATE_DIR"
printf '%s\n' "$target" >"$STATE_FILE"

if [[ "$target" == 1 ]]; then
    qs ipc call osd touchpad true
else
    qs ipc call osd touchpad false
fi
