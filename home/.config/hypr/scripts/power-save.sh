#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/powersave_mode"
PREV_BRIGHTNESS_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/powersave_prev_brightness"

_is_active() {
    [[ -f "$STATE_FILE" ]]
}

_set_refresh_rate() {
    local target_hz="$1"
    local mon_info
    mon_info=$(hyprctl monitors -j | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    for m in data:
        if "BOE" in m.get("description", "") or m.get("name") == "eDP-2":
            desc = "desc:" + m["description"] if m.get("description") else m["name"]
            print(f"{desc}|{m[\"x\"]}x{m[\"y\"]}|{m[\"scale\"]}")
            break
except Exception:
    pass
' 2>/dev/null || true)

    local desc="desc:BOE 0x0998"
    local pos="320x1440"
    local scale="1"

    if [[ -n "$mon_info" ]]; then
        IFS="|" read -r desc pos scale <<<"$mon_info"
    fi

    hyprctl eval "hl.monitor({ output = '${desc}', mode = '1920x1080@${target_hz}', position = '${pos}', scale = ${scale} })" >/dev/null 2>&1 || true
}

_status() {
    if _is_active; then
        printf '%s\n' '{"text": "󰌪", "alt": "on", "class": "on", "tooltip": "Power Saving Mode: ON\n• Refresh rate: 60 Hz\n• Animations & blur: Disabled\n• Brightness: Reduced (-20%)\n• Profile: Power-saver (Lenovo Quiet)\n\nClick to disable"}'
    else
        printf '%s\n' '{"text": "󰌪", "alt": "off", "class": "off", "tooltip": "Power Saving Mode: OFF\n• Refresh rate: 165 Hz\n• Animations & blur: Enabled\n\nClick to enable"}'
    fi
}

_enable() {
    touch "$STATE_FILE"

    _set_refresh_rate 60

    if command -v brightnessctl >/dev/null 2>&1; then
        local cur_b
        cur_b=$(brightnessctl get 2>/dev/null || echo "")
        if [[ -n "$cur_b" ]]; then
            echo "$cur_b" >"$PREV_BRIGHTNESS_FILE"
        fi
        brightnessctl -n 5 set 20%- >/dev/null 2>&1 || true
    fi

    hyprctl eval "hl.config({ animations = { enabled = false }, decoration = { blur = { enabled = false }, shadow = { enabled = false } } })" >/dev/null 2>&1 || true

    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set power-saver >/dev/null 2>&1 || true
    fi

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u low -i battery-profile-power-saver "Power Saver" "Enabled: 60Hz, animations off, -20% brightness" >/dev/null 2>&1 || true
    fi
}

_disable() {
    rm -f "$STATE_FILE"

    _set_refresh_rate 165

    if command -v brightnessctl >/dev/null 2>&1; then
        if [[ -f "$PREV_BRIGHTNESS_FILE" ]] && [[ -s "$PREV_BRIGHTNESS_FILE" ]]; then
            brightnessctl set "$(cat "$PREV_BRIGHTNESS_FILE")" >/dev/null 2>&1 || true
            rm -f "$PREV_BRIGHTNESS_FILE"
        else
            brightnessctl set +20% >/dev/null 2>&1 || true
        fi
    fi

    hyprctl eval "hl.config({ animations = { enabled = true }, decoration = { blur = { enabled = true }, shadow = { enabled = true } } })" >/dev/null 2>&1 || true

    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set balanced >/dev/null 2>&1 || true
    fi

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u low -i battery-profile-balanced "Power Saver" "Disabled: 165Hz, animations on, balanced profile" >/dev/null 2>&1 || true
    fi
}

_toggle() {
    if _is_active; then
        _disable
    else
        _enable
    fi
    pkill -RTMIN+8 -x waybar 2>/dev/null || true
}

case "${1:-}" in
--status) _status ;;
--enable)
    _enable
    pkill -RTMIN+8 -x waybar 2>/dev/null || true
    ;;
--disable)
    _disable
    pkill -RTMIN+8 -x waybar 2>/dev/null || true
    ;;
*) _toggle ;;
esac
