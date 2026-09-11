#!/usr/bin/env bash
# Toggles Hyprland power-save mode (refresh rate 60/165Hz, animations, blur, brightness, ghostty shader, opencode anims). Usage: [--status|--enable|--disable|--auto]
set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/powersave_mode"
PREV_BRIGHTNESS_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/powersave_prev_brightness"
GHOSTTY_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
OPENCODE_KV="${XDG_STATE_HOME:-$HOME/.local/state}/opencode/kv.json"

_is_active() {
    [[ -f "$STATE_FILE" ]]
}

bri() {
    command -v brightnessctl >/dev/null 2>&1 || return 0
    # Pin to the backlight class so LED devices are never touched.
    brightnessctl -c backlight "$@" >/dev/null 2>&1 || true
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

_ghostty_shader() { # $1: on|off (ghostty live-reloads the config file)
    [[ -f "$GHOSTTY_CONFIG" ]] || return 0
    if [[ "$1" == "off" ]]; then
        sed -i 's/^custom-shader /#custom-shader /; s/^custom-shader-animation = true/#custom-shader-animation = true/' "$GHOSTTY_CONFIG"
    else
        sed -i 's/^#custom-shader /custom-shader /; s/^#custom-shader-animation = true/custom-shader-animation = true/' "$GHOSTTY_CONFIG"
    fi
}

_opencode_anims() { # $1: true|false (persists TUI animation state in kv.json for NEW sessions only)
    # Upstream has no watcher or reload IPC: packages/tui/src/context/kv.tsx
    # reads kv.json once at startup and kv.set() updates memory + disk together.
    # External edits apply to the next launched TUI; running TUIs need a
    # manual Commands > Disable/Enable animations or a restart.
    local enabled="$1"
    [[ "$enabled" == "true" || "$enabled" == "false" ]] || return 0
    mkdir -p "$(dirname "$OPENCODE_KV")"
    if [[ ! -f "$OPENCODE_KV" ]]; then
        printf '{"animations_enabled":%s}' "$enabled" >"$OPENCODE_KV"
        return 0
    fi
    local tmp
    tmp=$(mktemp) || return 0
    if command -v jq >/dev/null 2>&1; then
        jq --argjson v "$enabled" '.animations_enabled = $v' "$OPENCODE_KV" >"$tmp" 2>/dev/null && mv "$tmp" "$OPENCODE_KV" || rm -f "$tmp"
    else
        python3 -c 'import json,sys; p=sys.argv[1]; v=sys.argv[2]=="true"; d=json.load(open(p)); d["animations_enabled"]=v; json.dump(d,open(p,"w"))' "$OPENCODE_KV" "$enabled" 2>/dev/null || true
        rm -f "$tmp"
    fi
}

_on_battery() {
    local f online
    for f in /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online /sys/class/power_supply/ucsi-source-psy-*/online; do
        [[ -f "$f" ]] || continue
        read -r online <"$f" 2>/dev/null || continue
        [[ "$online" == "1" ]] && return 1
    done
    local b
    for b in /sys/class/power_supply/BAT*/status; do
        [[ -f "$b" ]] || continue
        grep -qx "Discharging" "$b" 2>/dev/null && return 0
    done
    return 1
}

_status() {
    if _is_active; then
        printf '%s\n' '{"text": "󰌪", "alt": "on", "class": "on", "tooltip": "Power Saving Mode: ON\n• Refresh rate: 60 Hz\n• Animations &amp; blur: Disabled\n• Ghostty shader: Disabled\n• OpenCode anims: Disabled\n• Brightness: Reduced (-20%)\n• Profile: Power-saver (Lenovo Quiet)\n\nClick to disable"}'
    else
        printf '%s\n' '{"text": "󰌪", "alt": "off", "class": "off", "tooltip": "Power Saving Mode: OFF\n• Refresh rate: 165 Hz\n• Animations &amp; blur: Enabled\n• Ghostty shader: Enabled\n• OpenCode anims: Enabled\n\nClick to enable"}'
    fi
}

_enable() {
    # Called as "_enable --no-brightness" from _auto: the EC firmware already
    # dims on power-source change, so touching brightness there too would
    # double-step (the "jumping brightness" on battery). Manual toggles keep
    # the brightness step.
    local with_brightness=true
    [[ "${1:-}" == "--no-brightness" ]] && with_brightness=false

    touch "$STATE_FILE"

    if $with_brightness && command -v brightnessctl >/dev/null 2>&1; then
        local cur_b
        cur_b=$(brightnessctl -c backlight get 2>/dev/null || echo "")
        if [[ ! -f "$PREV_BRIGHTNESS_FILE" ]] && [[ -n "$cur_b" ]]; then
            echo "$cur_b" >"$PREV_BRIGHTNESS_FILE"
        fi
        bri --min-value=5 set 20%-
    fi

    _set_refresh_rate 60
    _set_look false
    _ghostty_shader off
    _opencode_anims false
    prof power-saver
    note -i battery "Power Saver" "Enabled: 60Hz, animations off, shader off, opencode anims off, -20% brightness"
}

_disable() {
    local with_brightness=true
    [[ "${1:-}" == "--no-brightness" ]] && with_brightness=false

    rm -f "$STATE_FILE"

    if $with_brightness && command -v brightnessctl >/dev/null 2>&1; then
        local prev_b=""
        if [[ -f "$PREV_BRIGHTNESS_FILE" ]] && [[ -s "$PREV_BRIGHTNESS_FILE" ]]; then
            prev_b=$(cat "$PREV_BRIGHTNESS_FILE")
            rm -f "$PREV_BRIGHTNESS_FILE"
        fi

        local cur_b
        cur_b=$(brightnessctl -c backlight get 2>/dev/null || echo "")

        if [[ -n "$prev_b" ]] && [[ -n "$cur_b" ]] && (( prev_b > cur_b )); then
            bri set "$prev_b"
        else
            bri set +20%
        fi
    fi

    _set_refresh_rate 165
    _set_look true
    _ghostty_shader on
    _opencode_anims true
    prof balanced
    note -i battery-profile-balanced "Power Saver" "Disabled: 165Hz, animations on, opencode anims on, balanced profile"
}

_toggle() {
    if _is_active; then
        _disable
    else
        _enable
    fi
    _signal_waybar
}

# Idempotent sync with actual power source; safe for timer polling.
_auto() {
    # Debounce: the power-supply sysfs state flaps briefly around plug/unplug
    # (and BAT status can read "Unknown" mid-transition). Acting on a single
    # sample toggles refresh rate / profile / brightness back and forth, which
    # reads as jumping brightness. Require two agreeing samples.
    local first=""
    _on_battery && first="battery" || first="ac"
    sleep 3
    local second=""
    _on_battery && second="battery" || second="ac"
    [[ "$first" == "$second" ]] || return 0

    if [[ "$second" == "battery" ]]; then
        if ! _is_active; then
            _enable --no-brightness
            _signal_waybar
        fi
    else
        if _is_active; then
            _disable --no-brightness
            _signal_waybar
        fi
    fi
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
--auto) _auto ;;
*) _toggle ;;
esac
