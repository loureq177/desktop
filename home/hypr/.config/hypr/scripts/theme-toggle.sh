#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="$HOME/.cache/theme-mode"
if [[ -f "$STATE_FILE" ]]; then
    current=$(cat "$STATE_FILE")
else
    current="dark"
fi

if [[ "$current" == "dark" ]]; then
    mode="light"
else
    mode="dark"
fi

notify() {
    local icon
    if [[ "$mode" == "dark" ]]; then
        icon="weather-clear-night"
    else
        icon="weather-clear"
    fi
    notify-send -a "Themes" -t 2000 -i "$icon" -h string:x-canonical-private-synchronous:theme \
        "Theme Switched to $mode mode"
}

apply_gsettings() {
    if [[ "$mode" == "dark" ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
        gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
        gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
    else
        gsettings set org.gnome.desktop.interface gtk-theme "Adwaita"
        gsettings set org.gnome.desktop.interface color-scheme "prefer-light"
        gsettings set org.gnome.desktop.interface icon-theme "Papirus"
    fi
}

apply_mako() {
    local cfg="$HOME/.config/mako/config"
    if [[ ! -f "$cfg" ]]; then return; fi
    sed -i "0,/^format=/s|^format=.*|format=<b>%a</b>\\\\n%s: %b|" "$cfg"
    if [[ "$mode" == "dark" ]]; then
        sed -i "s/^background-color=.*/background-color=#1e1e2e/" "$cfg"
        sed -i "s/^text-color=.*/text-color=#cdd6f4/" "$cfg"
        sed -i "0,/^border-color=#/s/^border-color=#.*/border-color=#89b4fa/" "$cfg"
        sed -i "s/^progress-color=.*/progress-color=over #89b4fa/" "$cfg"
        sed -i "/^\[urgency=critical\]/,/^\[/s/^border-color=.*/border-color=#f38ba8/" "$cfg"
    else
        sed -i "s/^background-color=.*/background-color=#e1e2e7/" "$cfg"
        sed -i "s/^text-color=.*/text-color=#3760bf/" "$cfg"
        sed -i "0,/^border-color=#/s/^border-color=#.*/border-color=#2e7de9/" "$cfg"
        sed -i "s/^progress-color=.*/progress-color=over #2e7de9/" "$cfg"
        sed -i "/^\[urgency=critical\]/,/^\[/s/^border-color=.*/border-color=#e64553/" "$cfg"
    fi
    makoctl reload || true
}

apply_rofi() {
    local rasi="$HOME/.config/rofi/tokyonight.rasi"
    if [[ ! -f "$rasi" ]]; then return; fi
    if [[ "$mode" == "dark" ]]; then
        sed -i "s/^    fg0: .*/    fg0: #c8d3f5;/" "$rasi"
        sed -i "s/^    accent: .*/    accent: #2ccade;/" "$rasi"
        sed -i "/^window {/,/^}/s/background-color:.*/background-color: rgba(34, 36, 54, 0.95);/" "$rasi"
        sed -i "/^inputbar {/,/^}/s/background-color:.*/background-color: rgba(47, 51, 77, 0.4);/" "$rasi"
        sed -i "/^element selected {/,/^}/s/background-color:.*/background-color: rgba(47, 51, 77, 0.4);/" "$rasi"
        sed -i "s/placeholder-color: .*/placeholder-color: #565f89;/" "$rasi"
    else
        sed -i "s/^    fg0: .*/    fg0: #3760bf;/" "$rasi"
        sed -i "s/^    accent: .*/    accent: #2e7de9;/" "$rasi"
        sed -i "/^window {/,/^}/s/background-color:.*/background-color: rgba(225, 226, 231, 0.95);/" "$rasi"
        sed -i "/^inputbar {/,/^}/s/background-color:.*/background-color: rgba(196, 200, 218, 0.4);/" "$rasi"
        sed -i "/^element selected {/,/^}/s/background-color:.*/background-color: rgba(196, 200, 218, 0.4);/" "$rasi"
        sed -i "s/placeholder-color: .*/placeholder-color: #888888;/" "$rasi"
    fi
}

apply_ghostty() {
    local cfg="$HOME/.config/ghostty/config"
    if [[ ! -f "$cfg" ]]; then return; fi
    if [[ "$mode" == "dark" ]]; then
        sed -i 's/^theme = .*/theme = "TokyoNight Moon"/' "$cfg"
    else
        sed -i 's/^theme = .*/theme = "TokyoNight Day"/' "$cfg"
    fi
    pkill -USR2 -x ghostty || true
}

apply_btop() {
    local cfg="$HOME/.config/btop/btop.conf"
    if [[ ! -f "$cfg" ]]; then return; fi
    if [[ "$mode" == "dark" ]]; then
        sed -i 's/^color_theme = .*/color_theme = "tokyonight_moon.theme"/' "$cfg"
    else
        sed -i 's/^color_theme = .*/color_theme = "tokyonight_day.theme"/' "$cfg"
    fi
}

apply_hyprland_borders() {
    if [[ "$mode" == "dark" ]]; then
        hyprctl keyword general:col.active_border "rgba(33ccffee) rgba(00ff99ee) 45deg" >/dev/null 2>&1 || true
        hyprctl keyword general:col.inactive_border "rgba(595959aa)" >/dev/null 2>&1 || true
    else
        hyprctl keyword general:col.active_border "rgba(2e7de9ee) rgba(0f9cbaee) 45deg" >/dev/null 2>&1 || true
        hyprctl keyword general:col.inactive_border "rgba(888888aa)" >/dev/null 2>&1 || true
    fi
}

apply_wallpaper() {
    local wallpaper="$HOME/Pictures/Wallpapers/hyprland-${mode}.png"
    if [[ ! -f "$wallpaper" ]]; then return; fi
    pkill -x swaybg || true
    swaybg -i "$wallpaper" -m fill >/dev/null 2>&1 &
    disown
}

apply_waybar() {
    local css="$HOME/.config/waybar/style.css"
    if [[ ! -f "$css" ]]; then return; fi
    if [[ "$mode" == "dark" ]]; then
        sed -i "s/^@define-color text .*/@define-color text #ffffff;/" "$css"
        sed -i "s/^@define-color text-inactive .*/@define-color text-inactive #aaaaaa;/" "$css"
        sed -i "s/^@define-color hover-bg .*/@define-color hover-bg rgba(255, 255, 255, 0.1);/" "$css"
        sed -i "s/^@define-color dnd-off .*/@define-color dnd-off #a6adc8;/" "$css"
    else
        sed -i "s/^@define-color text .*/@define-color text #1e1e2e;/" "$css"
        sed -i "s/^@define-color text-inactive .*/@define-color text-inactive #888888;/" "$css"
        sed -i "s/^@define-color hover-bg .*/@define-color hover-bg rgba(0, 0, 0, 0.1);/" "$css"
        sed -i "s/^@define-color dnd-off .*/@define-color dnd-off #6c7086;/" "$css"
    fi
}

signal_waybar() {
    local old_pids
    old_pids=$(pgrep -x waybar) || true
    waybar >/dev/null 2>&1 &
    disown
    if [[ -n "$old_pids" ]]; then
        sleep 0.3
        for pid in $old_pids; do
            kill "$pid" 2>/dev/null || true
        done
    fi
}

echo "$mode" >"$STATE_FILE"

apply_gsettings
apply_waybar
apply_rofi
apply_ghostty
apply_btop
apply_hyprland_borders
apply_wallpaper
apply_mako

notify
signal_waybar
