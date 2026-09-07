#!/usr/bin/env bash
# Toggles Hyprland power-save mode (refresh rate 60/165Hz, animations, blur, brightness). Usage: [--status|--enable|--disable]
set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/powersave_mode"
PREV_BRIGHTNESS_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/powersave_prev_brightness"

_is_active() {
    [[ -f "$STATE_FILE" ]]
}

bri() {
    command -v brightnessctl >/dev/null 2>&1 || return 0
    brightnessctl "$@" >/dev/null 2>&1 || true
}

prof() {
    command -v powerprofilesctl >/dev/null 2>&1 || return 0
    powerprofilesctl set "$1" >/dev/null 2>&1 || true
}

note() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -u low "$@" >/dev/null 2>&1 || true
}

_signal_waybar() {
    pkill -RTMIN+8 -x waybar 2>/dev/null || true
}

_set_look() { # $1: true|false
    hyprctl eval "hl.config({ animations = { enabled = $1 }, decoration = { blur = { enabled = $1 }, shadow = { enabled = $1 } } })" >/dev/null 2>&1 || true
}

_set_refresh_rate() {
    local target_hz="$1"
    local mon_info
    mon_info=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select((.description // "" | contains("BOE")) or .name == "eDP-2") | "\(if .description and (.description | length > 0) then "desc:\(.description)" else .name end)|\(.x)x\(.y)|\(.scale)"' 2>/dev/null | head -n 1 || true)

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
        printf '%s\n' '{"text": "󰌪", "alt": "on", "class": "on", "tooltip": "Power Saving Mode: ON\n• Refresh rate: 60 Hz\n• Animations &amp; blur: Disabled\n• Brightness: Reduced (-20%)\n• Profile: Power-saver (Lenovo Quiet)\n\nClick to disable"}'
    else
        printf '%s\n' '{"text": "󰌪", "alt": "off", "class": "off", "tooltip": "Power Saving Mode: OFF\n• Refresh rate: 165 Hz\n• Animations &amp; blur: Enabled\n\nClick to enable"}'
    fi
}

_enable() {
    touch "$STATE_FILE"

    if command -v brightnessctl >/dev/null 2>&1; then
        local cur_b
        cur_b=$(brightnessctl get 2>/dev/null || echo "")
        if [[ ! -f "$PREV_BRIGHTNESS_FILE" ]] && [[ -n "$cur_b" ]]; then
            echo "$cur_b" >"$PREV_BRIGHTNESS_FILE"
        fi
        bri --min-value=5 set 20%-
    fi

    _set_refresh_rate 60
    _set_look false
    prof power-saver
    note -i battery "Power Saver" "Enabled: 60Hz, animations off, -20% brightness"
}

_disable() {
    rm -f "$STATE_FILE"

    if command -v brightnessctl >/dev/null 2>&1; then
        local prev_b=""
        if [[ -f "$PREV_BRIGHTNESS_FILE" ]] && [[ -s "$PREV_BRIGHTNESS_FILE" ]]; then
            prev_b=$(cat "$PREV_BRIGHTNESS_FILE")
            rm -f "$PREV_BRIGHTNESS_FILE"
        fi

        local cur_b
        cur_b=$(brightnessctl get 2>/dev/null || echo "")

        if [[ -n "$prev_b" ]] && [[ -n "$cur_b" ]] && (( prev_b > cur_b )); then
            bri set "$prev_b"
        else
            bri set +20%
        fi
    fi

    _set_refresh_rate 165
    _set_look true
    prof balanced
    note -i battery-profile-balanced "Power Saver" "Disabled: 165Hz, animations on, balanced profile"
}

_toggle() {
    if _is_active; then
        _disable
    else
        _enable
    fi
    _signal_waybar
}

case "${1:-}" in
--status) _status ;;
--enable)
    _enable
    _signal_waybar
    ;;
--disable)
    _disable
    _signal_waybar
    ;;
*) _toggle ;;
esac
