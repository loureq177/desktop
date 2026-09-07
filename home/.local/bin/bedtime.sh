#!/usr/bin/env bash
# Bedtime enforcer: sends curfew notifications and toggles WiFi off at 22:00, back on at 07:00.
set -euo pipefail

notify_bed() {
    notify-send \
        --app-name "Bedtime" \
        -t 0 "Bedtime" \
        -i "weather-clear-night" \
        "$1" 2>/dev/null || true
}

set_wifi() {
    local want
    case "$1" in
        off) want=disabled ;;
        on) want=enabled ;;
        *) return 0 ;;
    esac
    if [ "$(nmcli radio wifi 2>/dev/null || echo unknown)" != "$want" ]; then
        nmcli radio wifi "$1" 2>/dev/null || true
    fi
}

case $(date +%H:%M) in
    "21:45")
        notify_bed "WiFi will turn off in 15 minutes."
        ;;
    "21:55")
        notify_bed "WiFi will turn off in 5 minutes."
        ;;
    "22:00")
        notify_bed "WiFi has been turned off."
        set_wifi "off"
        ;;
    "07:00")
        set_wifi "on"
        ;;
    *)
        hour=$((10#$(date +%H)))
        if [ "$hour" -ge 22 ] || [ "$hour" -lt 7 ]; then
            notify_bed "WiFi has been turned off."
            set_wifi "off"
        elif [ "$hour" -ge 7 ] && [ "$hour" -lt 22 ]; then
            set_wifi "on"
        fi
        ;;
esac
