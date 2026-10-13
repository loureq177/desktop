#!/usr/bin/env bats
# apply-ui: ui.toml -> hypr/ui.lua, ui/ui.sh, yazi/theme.toml, quickshell/Theme.qml
# and the palette templates (btop, lazygit, hyprlock)

load helpers

setup() {
    sandbox_setup
    CFG="$HOME/.config"
    TOML="$CFG/ui/ui.toml"
    stub gsettings
    stub hyprctl
    stub pgrep 'exit 0'
    printf '#!/bin/bash\necho "power-save $*" >>"%s"\n' "$CALLS" >"$BIN/power-save"
}

apply_ui() { sut "$BIN/apply-ui" "$@"; }

# toml KEY.PATH: value from the sandbox ui.toml.
toml() {
    python3 - "$TOML" "$1" <<'EOF'
import sys, tomllib
value = tomllib.load(open(sys.argv[1], "rb"))
for part in sys.argv[2].split("."):
    value = value[part]
print(value)
EOF
}

lua_value() {
    lua -e "local t = dofile('$CFG/hypr/ui.lua'); print(t.$1)"
}

@test "apply-ui: generates every themed config file" {
    rm -f "$CFG/ui/ui.sh"
    apply_ui --no-reload
    assert_status 0
    [[ -s "$CFG/hypr/ui.lua" && -s "$CFG/ui/ui.sh" && -s "$CFG/yazi/theme.toml" && -s "$CFG/quickshell/Theme.qml" ]]
    [[ -s "$CFG/btop/themes/github-dark.theme" && -s "$CFG/lazygit/config.yml" && -s "$CFG/hypr/hyprlock.conf" ]]
    # No placeholder survives rendering.
    ! grep -nE '@[a-z_]+(:bare)?@' "$CFG/btop/themes/github-dark.theme" "$CFG/lazygit/config.yml" "$CFG/hypr/hyprlock.conf"
    refute_call_like "gsettings"
    refute_call_like "hyprctl"
}

@test "apply-ui: ui.lua is loadable and carries the ui.toml values" {
    need lua
    apply_ui --no-reload
    [[ "$(lua_value border.size)" == "$(toml border.size)" ]]
    [[ "$(lua_value rounding.window)" == "$(toml rounding.window)" ]]
    [[ "$(lua_value spacing.gaps_out)" == "$(toml spacing.gaps_out)" ]]
    [[ "$(lua_value font.mono)" == "$(toml font.mono)" ]]
    [[ "$(lua_value theme.cursor)" == "$(toml theme.cursor)" ]]
    local border
    border="$(toml colors.border)"
    [[ "$(lua_value colors.border)" == "rgba(${border#\#}ee)" ]] || fail "$(lua_value colors.border)"
}

@test "apply-ui: ui.sh gives shell scripts a slurp argument array and the fzf theme" {
    apply_ui --no-reload
    run bash -c 'set -eu; source "$1"; printf "%s\n" "${#SLURP_ARGS[@]}" "${SLURP_ARGS[@]}" "$UI_FZF_THEME"' _ "$CFG/ui/ui.sh"
    assert_status 0
    local accent bg
    accent="$(toml colors.accent_blue)"
    bg="$(toml colors.bg_main)"
    [[ "${lines[0]}" == 11 ]] || fail "$output"
    [[ "${lines[*]:1:11}" == "-d -b ${bg}b0 -c $accent -s ${accent}20 -w $(toml border.size) -B #00000000" ]] || fail "$output"
    [[ "${lines[12]}" == *"bg:$bg,"*"pointer:$accent,"* ]] || fail "$output"
}

@test "apply-ui: the yazi theme is valid toml" {
    apply_ui --no-reload
    python3 -c 'import sys, tomllib; t = tomllib.load(open(sys.argv[1], "rb")); assert t["mgr"]["cwd"]["fg"] and len(t["filetype"]["rules"]) >= 5' "$CFG/yazi/theme.toml"
}

@test "apply-ui: the quickshell theme is valid qml" {
    local qmllint=/usr/lib/qt6/bin/qmllint
    [[ -x "$qmllint" ]] || skip "needs Qt6 qmllint"
    apply_ui --no-reload
    run "$qmllint" "$CFG/quickshell/Theme.qml"
    assert_status 0
    grep -q "readonly property int borderSize: $(toml border.size)$" "$CFG/quickshell/Theme.qml"
}

@test "apply-ui: a change in ui.toml reaches every consumer" {
    sed -i -E 's/^(size *= *)[0-9]+/\17/' "$TOML"
    sed -i -E 's/^(accent_blue *= *)"#[0-9a-fA-F]+"/\1"#123456"/' "$TOML"
    [[ "$(toml border.size)" == 7 && "$(toml colors.accent_blue)" == "#123456" ]] || skip "ui.toml layout changed; adjust this test"
    apply_ui --no-reload
    assert_status 0
    grep -q 'size = 7,' "$CFG/hypr/ui.lua"
    grep -q 'accent_blue = "rgba(123456ee)"' "$CFG/hypr/ui.lua"
    grep -q -- '-c "#123456" -s "#12345620" -w 7 ' "$CFG/ui/ui.sh"
    grep -q 'cwd = { fg = "#123456", bold = true }' "$CFG/yazi/theme.toml"
    grep -q 'readonly property string accentBlue: "#123456"' "$CFG/quickshell/Theme.qml"
    grep -q 'readonly property int borderSize: 7$' "$CFG/quickshell/Theme.qml"
    grep -q 'theme\[hi_fg\]="#123456"' "$CFG/btop/themes/github-dark.theme"
    grep -q -- '- "#123456"' "$CFG/lazygit/config.yml"
    grep -q 'outer_color = rgba(123456ee) ' "$CFG/hypr/hyprlock.conf"
    grep -q 'outline_thickness = 7$' "$CFG/hypr/hyprlock.conf"
}

@test "apply-ui: the generated files committed to the repo are up to date" {
    apply_ui --no-reload
    assert_status 0
    local pair bad=0
    for pair in \
        "ui/ui.sh:archlinux/.config/ui/ui.sh" \
        "hypr/ui.lua:archlinux/.config/hypr/ui.lua" \
        "yazi/theme.toml:common/.config/yazi/theme.toml" \
        "quickshell/Theme.qml:archlinux/.config/quickshell/Theme.qml" \
        "btop/themes/github-dark.theme:common/.config/btop/themes/github-dark.theme" \
        "lazygit/config.yml:common/.config/lazygit/config.yml" \
        "hypr/hyprlock.conf:archlinux/.config/hypr/hyprlock.conf"; do
        if ! diff -u "$REPO/${pair#*:}" "$CFG/${pair%%:*}" >&2; then
            echo "STALE: ${pair#*:} (run apply-ui and commit the result)" >&2
            bad=1
        fi
    done
    [[ "$bad" -eq 0 ]]
}

@test "apply-ui: reloads Hyprland, re-applies power-save and updates GTK settings" {
    apply_ui
    assert_status 0
    assert_call "hyprctl reload"
    assert_call "power-save --reapply"
    assert_call "gsettings set org.gnome.desktop.interface cursor-theme $(toml theme.cursor)"
    assert_call "gsettings set org.gnome.desktop.interface icon-theme $(toml theme.icon)"
    assert_call "gsettings set org.gnome.desktop.interface gtk-theme $(toml theme.gtk)"
    assert_call "gsettings set org.gnome.desktop.interface font-name $(toml font.ui)"
    assert_call "gsettings set org.gnome.desktop.interface monospace-font-name $(toml font.mono) 12"
}

@test "apply-ui: leaves Hyprland alone when it is not running" {
    stub pgrep 'exit 1'
    apply_ui
    assert_status 0
    refute_call_like "hyprctl"
    refute_call_like "power-save"
    assert_call_like "gsettings set org.gnome.desktop.interface gtk-theme"
}

@test "apply-ui: fails without writing anything when ui.toml is broken" {
    rm -f "$CFG/ui/ui.sh"
    echo 'this is = not [valid toml' >>"$TOML"
    apply_ui --no-reload
    [[ "$status" -ne 0 ]]
    [[ ! -e "$CFG/hypr/ui.lua" && ! -e "$CFG/ui/ui.sh" && ! -e "$CFG/quickshell/Theme.qml" ]]
}
