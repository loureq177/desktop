#!/usr/bin/env bats
# power-save, power-save-watcher

load helpers

setup() {
    sandbox_setup
    STATE_FILE="$XDG_RUNTIME_DIR/powersave_mode"
    PREV_FILE="$XDG_RUNTIME_DIR/powersave_prev_brightness"
    PERF="$HOME/.local/state/ghostty/perf.conf"
    SHADER="$HOME/.local/state/ghostty/active-shader.glsl"
    KV="$HOME/.local/state/opencode/kv.json"
    cp -r "$REPO/archlinux/.config/ghostty" "$HOME/.config/ghostty"

    echo 200 >"$SANDBOX/brightness"
    stub brightnessctl "
case \"\$*\" in
'-c backlight get') cat '$SANDBOX/brightness' ;;
'-c backlight -m') echo 'amdgpu_bl1,backlight,128,50%,255' ;;
esac"
    cat >"$SANDBOX/monitors.json" <<'EOF'
[{"name":"DP-1","description":"iiyama PL2792Q","width":2560,"height":1440,"x":0,"y":0,"scale":1,
  "availableModes":["2560x1440@144.00Hz"]},
 {"name":"eDP-1","description":"BOE 0x0998","width":1920,"height":1080,"x":320,"y":1440,"scale":1.25,
  "availableModes":["2560x1440@240.00Hz","1920x1080@60.01Hz","1920x1080@165.00Hz","1920x1080@144.00Hz"]}]
EOF
    stub hyprctl "[[ \"\$1\" == monitors ]] && cat '$SANDBOX/monitors.json'; true"
    stub systemctl '[[ "$*" == *is-active* ]] && exit 3; true'
    stub pkill
    stub powerprofilesctl
    stub qs
    stub restore-backlight
}

# The scripts read the AC adapter straight from /sys, which a test cannot fake.
machine_on_ac() {
    local f found=false
    for f in /sys/class/power_supply/ADP*/online /sys/class/power_supply/AC*/online; do
        [[ -r "$f" ]] || continue
        found=true
        [[ "$(<"$f")" == 1 ]] && return 0
    done
    ! $found
}

display_call() {
    echo "hyprctl eval hl.monitor({ output = 'desc:BOE 0x0998', mode = '1920x1080@$1', position = '320x1440', scale = 1.25 }); hl.config({ decoration = { blur = { enabled = $2 } } })"
}

@test "power-save: turning it on dims, drops to 60 Hz without blur and saves power" {
    sut "$BIN/power-save"
    assert_status 0
    [[ -f "$STATE_FILE" ]]
    [[ "$(<"$PREV_FILE")" == 200 ]]
    assert_call "brightnessctl -c backlight --min-value=5 set 20%-"
    assert_call "$(display_call 60 false)"
    grep -qx "custom-shader-animation = false" "$PERF"
    grep -qx "background-opacity = 1.0" "$PERF"
    [[ "$(readlink "$SHADER")" == "$HOME/.config/ghostty/shaders/noop.glsl" ]]
    [[ "$(jq -c . "$KV")" == '{"animations_enabled":false}' ]]
    wait_for_call_like "powerprofilesctl set power-saver"
    wait_for_call_like "qs ipc call osd brightness 50"
    wait_for_call_like "restore-backlight"
}

@test "power-save: turning it off restores brightness, refresh rate, blur and profile" {
    sut "$BIN/power-save"
    echo 100 >"$SANDBOX/brightness"
    : >"$CALLS"
    sut "$BIN/power-save"
    assert_status 0
    [[ ! -e "$STATE_FILE" && ! -e "$PREV_FILE" ]]
    assert_call "brightnessctl -c backlight set 200"
    # Highest rate of the current resolution, not of any mode the panel lists.
    assert_call "$(display_call 165 true)"
    [[ "$(jq -c . "$KV")" == '{"animations_enabled":true}' ]]
    wait_for_call_like "powerprofilesctl set balanced"
}

@test "power-save: turning it off does not dim a screen the user brightened meanwhile" {
    sut "$BIN/power-save"
    echo 250 >"$SANDBOX/brightness"
    : >"$CALLS"
    sut "$BIN/power-save"
    assert_status 0
    assert_call "brightnessctl -c backlight set +20%"
    refute_call_like "set 200"
}

@test "power-save: ghostty eye-candy is on only on AC power and outside power-save" {
    sut "$BIN/power-save"
    sut "$BIN/power-save"
    if machine_on_ac; then
        grep -qx "custom-shader-animation = true" "$PERF"
        grep -qx "background-opacity = 0.80" "$PERF"
        [[ "$(readlink "$SHADER")" == "$HOME/.config/ghostty/shaders/cursor_warp.glsl" ]]
    else
        grep -qx "custom-shader-animation = false" "$PERF"
        [[ "$(readlink "$SHADER")" == "$HOME/.config/ghostty/shaders/noop.glsl" ]]
    fi
    [[ -f "$REPO/archlinux/.config/ghostty/shaders/noop.glsl" && -f "$REPO/archlinux/.config/ghostty/shaders/cursor_warp.glsl" ]]
}

@test "power-save: keeps the other opencode settings" {
    mkdir -p "${KV%/*}"
    echo '{"theme":"github","animations_enabled":true}' >"$KV"
    sut "$BIN/power-save"
    assert_status 0
    [[ "$(jq -c . "$KV")" == '{"theme":"github","animations_enabled":false}' ]]
}

@test "power-save: reloads ghostty through its service when that is how it runs" {
    stub systemctl 'true'
    sut "$BIN/power-save"
    assert_status 0
    wait_for_call_like "systemctl --user reload app-com.mitchellh.ghostty.service"
    refute_call_like "pkill"
}

@test "power-save: signals a standalone ghostty to reload" {
    sut "$BIN/power-save"
    assert_status 0
    wait_for_call_like "pkill -SIGUSR2 -x ghostty"
}

@test "power-save: works without a laptop panel" {
    echo '[{"name":"DP-1","description":"iiyama","width":2560,"height":1440,"x":0,"y":0,"scale":1,"availableModes":[]}]' >"$SANDBOX/monitors.json"
    sut "$BIN/power-save"
    assert_status 0
    [[ -f "$STATE_FILE" ]]
    refute_call_like "hyprctl eval"
    sut "$BIN/power-save"
    assert_status 0
    [[ ! -e "$STATE_FILE" ]]
}

@test "power-save: works without brightnessctl" {
    rm "$STUBS/brightnessctl"
    sut "$BIN/power-save"
    assert_status 0
    [[ -f "$STATE_FILE" && ! -e "$PREV_FILE" ]]
    assert_call "$(display_call 60 false)"
    sut "$BIN/power-save"
    assert_status 0
    [[ ! -e "$STATE_FILE" ]]
}

@test "power-save --reapply: re-applies 60 Hz only while power-save is on" {
    sut "$BIN/power-save" --reapply
    assert_status 0
    refute_call_like "hyprctl eval"

    sut "$BIN/power-save"
    : >"$CALLS"
    sut "$BIN/power-save" --reapply
    assert_status 0
    assert_call "$(display_call 60 false)"
    [[ -f "$STATE_FILE" ]]
    refute_call_like "brightnessctl"
}

@test "power-save --sync: leaves power-save when the charger is connected" {
    sut "$BIN/power-save"
    : >"$CALLS"
    sut "$BIN/power-save" --sync
    assert_status 0
    if machine_on_ac; then
        [[ ! -e "$STATE_FILE" ]]
        assert_call "$(display_call 165 true)"
    else
        [[ -f "$STATE_FILE" ]]
        refute_call_like "hyprctl eval"
    fi
}

@test "power-save --sync: reloads ghostty only when its settings changed" {
    sut "$BIN/power-save" --sync
    assert_status 0
    assert_call "pkill -SIGUSR2 -x ghostty"
    [[ -f "$PERF" && -L "$SHADER" ]]

    : >"$CALLS"
    sut "$BIN/power-save" --sync
    assert_status 0
    refute_call_like "pkill"
    refute_call_like "hyprctl eval"
}

# --- power-save-watcher ------------------------------------------------------

@test "power-save-watcher: syncs at start and on every power supply event" {
    printf '#!/bin/bash\necho "power-save $*" >>"%s"\n' "$CALLS" >"$BIN/power-save"
    stub udevadm "printf '%s\n' 'KERNEL[1.0] change /devices/ADP1 (power_supply)' 'UDEV  [1.1] change /devices/ADP1 (power_supply)' 'POWER_SUPPLY_ONLINE=1' '' 'UDEV  [9.1] change /devices/BAT0 (power_supply)'"
    sut "$BIN/power-save-watcher"
    assert_status 0
    if compgen -G "/sys/class/power_supply/ADP*/online" >/dev/null || compgen -G "/sys/class/power_supply/AC*/online" >/dev/null; then
        local _
        for _ in $(seq 1 60); do
            [[ "$(call_count "power-save --sync")" -ge 3 ]] && break
            "$REAL_SLEEP" 0.05
        done
        [[ "$(call_count "power-save --sync")" -eq 3 ]] || fail "$(calls)"
        assert_call "udevadm monitor --udev --property --subsystem-match=power_supply"
    else
        # Desktop: nothing to watch.
        refute_call_like "udevadm"
        refute_call_like "power-save"
    fi
}
