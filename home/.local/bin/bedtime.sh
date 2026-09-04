#!/usr/bin/env bash
set -euo pipefail

notify_bed() {
    notify-send \
        --app-name "Bedtime" \
        -t 0 "Bedtime" \
        -i "weather-clear-night" \
        "$1" 2>/dev/null || true
}

set_wifi() {
    local target="$1" # "on" or "off"
    local current
    current=$(nmcli radio wifi 2>/dev/null || echo "unknown")

    if [ "$target" = "off" ]; then
        if [ "$current" != "disabled" ]; then
            nmcli radio wifi off 2>/dev/null || true
        fi
    elif [ "$target" = "on" ]; then
        if [ "$current" != "enabled" ]; then
            nmcli radio wifi on 2>/dev/null || true
        fi
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
