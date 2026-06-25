#!/usr/bin/env bash
set -euo pipefail

STATE_DUPA="$HOME/.cache/theme-mode"
if [[ -f "$STATE_DUPA" ]]; then
    current=$(cat "$STATE_DUPA")
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
    notify-send --app-name "Theme" -t 2000 -i "$icon" -h string:x-canonical-private-synchronous:theme \
        "Themes" "Switched to $mode"
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

template_cp() {
    local src="$1" dst="$2" label="$3"
    if [[ ! -f "$src" ]]; then
        notify-send -u critical "Theme" "$label: missing $src"
        return 1
    fi
    cp "$src" "$dst"
}

# --- CSS selectors validation ---
validate_css_selectors() {
    local dark="$1" light="$2" label="$3"
    local missing

    missing=$(comm -23 \
        <(grep -oP '#custom-\w+' "$dark" | sort -u) \
        <(grep -oP '#custom-\w+' "$light" | sort -u) | tr '\n' ' ')
    if [[ -n "$missing" ]]; then
        notify-send -u critical "Theme" "$label: missing in light — $missing"
    fi

    missing=$(comm -23 \
        <(grep -oP '#custom-\w+' "$light" | sort -u) \
        <(grep -oP '#custom-\w+' "$dark" | sort -u) | tr '\n' ' ')
    if [[ -n "$missing" ]]; then
        notify-send -u critical "Theme" "$label: missing in dark — $missing"
    fi
}

apply_waybar() {
    local dir="$HOME/.config/waybar"
    local dst="$dir/style.css"
    local dark="$dir/style-dark.css"
    local light="$dir/style-light.css"
    if [[ ! -f "$dst" ]]; then return; fi
    validate_css_selectors "$dark" "$light" "Waybar"
    template_cp "$dir/style-${mode}.css" "$dst" "Waybar"
}

# --- Rasi selectors validation ---
validate_rasi_sections() {
    local dark="$1" light="$2" label="$3"
    local extract='^\w[\w -]*(?=\s*\{)'
    local missing

    missing=$(comm -23 \
        <(grep -oP "$extract" "$dark" | sed 's/ *$//' | sort -u) \
        <(grep -oP "$extract" "$light" | sed 's/ *$//' | sort -u) | tr '\n' '|')
    if [[ -n "$missing" ]]; then
        notify-send -u critical "Theme" "$label: missing in light — ${missing//|/, }"
    fi

    missing=$(comm -23 \
        <(grep -oP "$extract" "$light" | sed 's/ *$//' | sort -u) \
        <(grep -oP "$extract" "$dark" | sed 's/ *$//' | sort -u) | tr '\n' '|')
    if [[ -n "$missing" ]]; then
        notify-send -u critical "Theme" "$label: missing in dark — ${missing//|/, }"
    fi
}

apply_rofi() {
    local dir="$HOME/.config/rofi"
    local dst="$dir/tokyonight.rasi"
    if [[ ! -f "$dst" ]]; then return; fi
    validate_rasi_sections "$dir/tokyonight-dark.rasi" "$dir/tokyonight-light.rasi" "Rofi"
    template_cp "$dir/tokyonight-${mode}.rasi" "$dst" "Rofi"
}

apply_ghostty() {
    local dir="$HOME/.config/ghostty"
    local dst="$dir/config"
    if [[ ! -f "$dst" ]]; then return; fi
    template_cp "$dir/config-${mode}" "$dst" "Ghostty"
    pkill -USR2 -x ghostty || true
}

apply_btop() {
    local dir="$HOME/.config/btop"
    local dst="$dir/btop.conf"
    if [[ ! -f "$dst" ]]; then return; fi
    template_cp "$dir/btop-${mode}.conf" "$dst" "Btop"
}

apply_opencode() {
    local dir="$HOME/.config/opencode"
    local dst="$dir/tui.json"
    if [[ ! -f "$dst" ]]; then return; fi
    template_cp "$dir/tui-${mode}.json" "$dst" "Opencode"
    pkill -USR2 -x opencode || true
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

signal_waybar() {
    pkill -USR2 waybar || true
}

echo "$mode" >"$STATE_DUPA"

apply_gsettings
apply_waybar
apply_rofi
apply_ghostty
apply_btop
apply_opencode
apply_hyprland_borders
apply_wallpaper

notify
signal_waybar
