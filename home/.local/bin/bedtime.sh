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

hour=$((10#$(date +%H)))
minute=$((10#$(date +%M)))
now=$((hour * 60 + minute))
curfew=$((22 * 60))
morning=$((7 * 60))

if [ "$now" -ge "$curfew" ] || [ "$now" -lt "$morning" ]; then
    # Warn only shortly after curfew: Persistent=true catch-up runs (after
    # sleep/boot) must not re-notify in the middle of the night.
    if [ "$now" -ge "$curfew" ] && [ "$now" -lt $((curfew + 15)) ]; then
        notify_bed "WiFi has been turned off."
    fi
    set_wifi "off"
elif [ "$hour" -eq 21 ] && [ "$minute" -ge 45 ]; then
    # Minute ranges instead of exact HH:MM so a catch-up run at e.g. 21:47
    # still warns, with the real remaining time.
    notify_bed "WiFi will turn off in $((curfew - now)) minutes."
    set_wifi "on"
else
    set_wifi "on"
fi
