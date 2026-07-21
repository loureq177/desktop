#!/usr/bin/env bash
set -euo pipefail

notify_bed() {
    notify-send \
        --app-name "Bedtime" \
        -t 0 "Bedtime" \
        -i "weather-clear-night" \
        "$1"
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
        nmcli radio wifi off
        ;;
    "07:00")
        nmcli radio wifi on
        ;;
    *)
        hour=$(10#$(date +%H))
        if [ "$hour" -ge 22 ] || [ "$hour" -lt 2 ]; then
            notify_bed "WiFi has been turned off."
            nmcli radio wifi off
        elif [ "$hour" -ge 7 ] && [ "$hour" -lt 21 ]; then
            nmcli radio wifi on
        fi
        ;;
esac

