#!/usr/bin/env bats
# wallpaper, weather, weather-location, bedtime, check-updates, awake-toggle,
# quickshell-session

load helpers

setup() {
    sandbox_setup
    stub qs
    stub notify-send
    WALLS="$HOME/Pictures/Wallpapers"
    WALL_STATE="$HOME/.cache/wallpaper/current"
    LOC_FILE="$HOME/.local/state/weather/weather.json"
}

# --- wallpaper ---------------------------------------------------------------

walls() {
    mkdir -p "$WALLS"
    local f
    for f in "$@"; do : >"$WALLS/$f"; done
}

@test "wallpaper: without a subcommand prints usage and fails" {
    sut "$BIN/wallpaper"
    assert_status 1
    assert_output_like "usage: wallpaper next|init"
}

@test "wallpaper init: picks hyprland.png from the wallpaper dir" {
    walls a.png hyprland.png
    sut "$BIN/wallpaper" init
    assert_status 0
    [[ "$(<"$WALL_STATE")" == "$WALLS/hyprland.png" ]]
}

@test "wallpaper init: falls back to the wallpaper shipped with the hypr config" {
    mkdir -p "$HOME/.config/hypr/wallpapers"
    : >"$HOME/.config/hypr/wallpapers/hyprland.png"
    sut "$BIN/wallpaper" init
    assert_status 0
    [[ "$(<"$WALL_STATE")" == "$HOME/.config/hypr/wallpapers/hyprland.png" ]]
}

@test "wallpaper init: keeps an already chosen wallpaper" {
    walls a.png hyprland.png
    mkdir -p "${WALL_STATE%/*}"
    echo "$WALLS/a.png" >"$WALL_STATE"
    sut "$BIN/wallpaper" init
    assert_status 0
    [[ "$(<"$WALL_STATE")" == "$WALLS/a.png" ]]
}

@test "wallpaper init: replaces a saved wallpaper that no longer exists" {
    walls b.jpg
    mkdir -p "${WALL_STATE%/*}"
    echo "$WALLS/gone.png" >"$WALL_STATE"
    sut "$BIN/wallpaper" init
    assert_status 0
    [[ "$(<"$WALL_STATE")" == "$WALLS/b.jpg" ]]
}

@test "wallpaper init: says so when there is no wallpaper at all" {
    sut "$BIN/wallpaper" init
    assert_status 1
    assert_output_like "no wallpapers in"
    [[ ! -e "$WALL_STATE" ]]
}

@test "wallpaper next: walks the images alphabetically and wraps around" {
    walls b.jpg a.png "c d.webp" e.JPEG notes.txt
    mkdir "$WALLS/subdir.png"
    local expected
    for expected in a.png b.jpg "c d.webp" e.JPEG a.png; do
        sut "$BIN/wallpaper" next
        assert_status 0
        [[ "$(<"$WALL_STATE")" == "$WALLS/$expected" ]] || fail "wanted $expected, got $(<"$WALL_STATE")"
    done
}

@test "wallpaper next: fails with a message when the dir has no images" {
    walls notes.txt
    sut "$BIN/wallpaper" next
    assert_status 1
    assert_output_like "no wallpapers in"
}

@test "wallpaper: WALL_DIR overrides the wallpaper dir" {
    mkdir -p "$SANDBOX/other"
    : >"$SANDBOX/other/x.png"
    WALL_DIR="$SANDBOX/other" sut "$BIN/wallpaper" next
    assert_status 0
    [[ "$(<"$WALL_STATE")" == "$SANDBOX/other/x.png" ]]
}

# --- weather -----------------------------------------------------------------

@test "weather: shows the status reported by the shell" {
    stub qs 'echo "Warsaw: 12°C"'
    sut "$BIN/weather"
    assert_status 0
    assert_call "qs ipc call weather status"
    assert_call "notify-send -u low --app-name Weather -i weather-clear Weather Warsaw: 12°C"
}

@test "weather: reports unavailable when the shell has no data" {
    local reply
    for reply in 'echo null' 'echo "Weather unavailable"' 'exit 1' 'true'; do
        : >"$CALLS"
        stub qs "$reply"
        sut "$BIN/weather"
        assert_status 0
        assert_call "notify-send -u low --app-name Weather -i dialog-warning Weather Weather information unavailable."
    done
}

# --- weather-location --------------------------------------------------------

@test "weather-location: without arguments prints usage and fails" {
    sut "$BIN/weather-location"
    assert_status 1
    assert_output_like "Usage: weather-location"
}

@test "weather-location --set: needs a name" {
    sut "$BIN/weather-location" --set
    [[ "$status" -ne 0 ]]
    [[ ! -e "$LOC_FILE" ]]
}

@test "weather-location --set name lat,lon: stores them and refreshes the shell" {
    sut "$BIN/weather-location" --set "São Paulo" "-23.55,-46.63"
    assert_status 0
    [[ "$(jq -c . "$LOC_FILE")" == '{"name":"São Paulo","latitude":-23.55,"longitude":-46.63}' ]]
    assert_call "qs ipc call weather refresh"
}

@test "weather-location --set name: geocodes the name" {
    stub curl 'echo "{\"results\":[{\"name\":\"Kraków\",\"latitude\":50.06,\"longitude\":19.94}]}"'
    sut "$BIN/weather-location" --set "Kraków"
    assert_status 0
    [[ "$(jq -c . "$LOC_FILE")" == '{"name":"Kraków","latitude":50.06,"longitude":19.94}' ]]
    assert_call_like "name=Kraków"
}

@test "weather-location --set name: keeps just the name when geocoding fails" {
    local reply
    for reply in 'exit 6' 'echo "{}"' 'echo "{\"results\":[]}"' 'echo "<html>"'; do
        stub curl "$reply"
        sut "$BIN/weather-location" --set 'O"Fallon'
        assert_status 0
        [[ "$(jq -c . "$LOC_FILE")" == '{"name":"O\"Fallon"}' ]] || fail "curl '$reply' gave: $(<"$LOC_FILE")"
    done
}

@test "weather-location: what it writes is what the weather widget reads" {
    need node
    sut "$BIN/weather-location" --set "Gdańsk" "54.35,18.65"
    assert_status 0
    run node -e '
        const m = require(process.argv[1]);
        const fs = require("fs");
        console.log(JSON.stringify(m.parseLocationFile(fs.readFileSync(process.argv[2], "utf8"))));
    ' "$REPO/archlinux/.config/quickshell/WeatherModel.js" "$LOC_FILE"
    [[ "$output" == '{"name":"Gdańsk","latitude":54.35,"longitude":18.65}' ]] || fail "$output"
}

@test "weather-location --clear: removes the location and refreshes the shell" {
    mkdir -p "${LOC_FILE%/*}"
    echo '{}' >"$LOC_FILE"
    sut "$BIN/weather-location" --clear
    assert_status 0
    [[ ! -e "$LOC_FILE" ]]
    assert_call "qs ipc call weather refresh"
}

# --- bedtime -----------------------------------------------------------------

# wifi STATE: what `nmcli radio wifi` reports.
wifi() {
    echo "$1" >"$SANDBOX/wifi"
    stub nmcli "[[ \"\$*\" == 'radio wifi' ]] && cat '$SANDBOX/wifi'; true"
}
BED_MARKER() { echo "$HOME/.local/state/bedtime/wifi-off"; }

@test "bedtime 21:50: warns and leaves wifi alone" {
    fake_time 21 50
    wifi enabled
    sut "$BIN/bedtime"
    assert_status 0
    assert_call_like "WiFi will turn off in 10 minutes."
    refute_call_like "nmcli radio wifi off"
}

@test "bedtime 22:00: turns wifi off, announces it and remembers doing so" {
    fake_time 22 00
    wifi enabled
    sut "$BIN/bedtime"
    assert_status 0
    assert_call "nmcli radio wifi off"
    assert_call_like "WiFi has been turned off."
    [[ -f "$(BED_MARKER)" ]]
}

@test "bedtime 23:30: turns wifi off without another notification" {
    fake_time 23 30
    wifi enabled
    sut "$BIN/bedtime"
    assert_status 0
    assert_call "nmcli radio wifi off"
    refute_call_like "notify-send"
}

@test "bedtime 22:00: does not claim a wifi the user had already switched off" {
    fake_time 22 00
    wifi disabled
    sut "$BIN/bedtime"
    assert_status 0
    refute_call_like "nmcli radio wifi off"
    [[ ! -e "$(BED_MARKER)" ]]
}

@test "bedtime 07:00: turns wifi back on only if bedtime turned it off" {
    fake_time 07 00
    wifi disabled
    sut "$BIN/bedtime"
    assert_status 0
    refute_call_like "nmcli radio wifi on"

    mkdir -p "$(dirname "$(BED_MARKER)")"
    : >"$(BED_MARKER)"
    sut "$BIN/bedtime"
    assert_status 0
    assert_call "nmcli radio wifi on"
    [[ ! -e "$(BED_MARKER)" ]]
}

@test "bedtime: copes with 08 and 09 (not octal)" {
    fake_time 08 09
    wifi enabled
    sut "$BIN/bedtime"
    assert_status 0
}

@test "bedtime: survives a missing NetworkManager" {
    fake_time 22 00
    stub nmcli 'exit 1'
    sut "$BIN/bedtime"
    assert_status 0
    [[ ! -e "$(BED_MARKER)" ]]
}

# --- check-updates -----------------------------------------------------------

CU_STAMP() { echo "$HOME/.local/state/check-updates/last-check"; }

updates_stubs() {
    # $1 official lines, $2 checkupdates exit, $3 aur lines, $4 pacnew lines
    stub checkupdates "printf '%s' '$1'; exit $2"
    stub paru "printf '%s' '$3'"
    stub pacdiff "printf '%s' '$4'"
    stub gdbus
}

@test "check-updates: notifies with the official and AUR counts" {
    updates_stubs $'a 1 -> 2\nb 1 -> 2\nc 1 -> 2\n' 0 $'x 1 -> 2\ny 1 -> 2\n' ''
    sut "$BIN/check-updates"
    assert_status 0
    assert_call_like "Available updates (5)"
    assert_call_like "Official packages: 3"
    assert_call_like "AUR packages: 2"
    assert_call_like '["update", "Update system"]'
    [[ "$(<"$(CU_STAMP)")" =~ ^[0-9]+$ ]]
}

@test "check-updates: stays quiet when everything is up to date" {
    updates_stubs '' 2 '' ''
    sut "$BIN/check-updates"
    assert_status 0
    refute_call_like "gdbus"
    [[ -f "$(CU_STAMP)" ]]
}

@test "check-updates: reports .pacnew files even without updates" {
    updates_stubs '' 2 '' $'/etc/pacman.conf.pacnew\n'
    sut "$BIN/check-updates"
    assert_status 0
    assert_call_like ".pacnew files detected (1)"
}

@test "check-updates: mentions .pacnew files next to the updates" {
    updates_stubs $'a 1 -> 2\n' 0 '' $'/etc/a.pacnew\n/etc/b.pacnew\n'
    sut "$BIN/check-updates"
    assert_status 0
    assert_call_like "Available updates (1)"
    assert_call_like ".pacnew files: 2"
}

@test "check-updates: skips the check inside the cooldown" {
    updates_stubs $'a 1 -> 2\n' 0 '' ''
    mkdir -p "$(dirname "$(CU_STAMP)")"
    echo "$(($(date +%s) - 600))" >"$(CU_STAMP)"
    sut "$BIN/check-updates"
    assert_status 0
    refute_call_like "checkupdates"
    refute_call_like "gdbus"
}

@test "check-updates: checks again after the cooldown or with a corrupt stamp" {
    updates_stubs $'a 1 -> 2\n' 0 '' ''
    mkdir -p "$(dirname "$(CU_STAMP)")"
    local stamp
    for stamp in "$(($(date +%s) - 10801))" "garbage" ""; do
        : >"$CALLS"
        echo "$stamp" >"$(CU_STAMP)"
        sut "$BIN/check-updates"
        assert_status 0
        assert_call_like "Available updates (1)"
    done
}

@test "check-updates: a failed check is not recorded, so it is retried" {
    updates_stubs '' 1 '' ''
    sut "$BIN/check-updates"
    assert_status 0
    refute_call_like "gdbus"
    [[ ! -e "$(CU_STAMP)" ]]
}

# --- awake-toggle ------------------------------------------------------------

awake_stubs() {
    # $1: exit status of `systemctl --user is-active`
    stub systemctl "case \"\$*\" in *is-active*) exit $1 ;; *show*) echo 4242 ;; esac"
    stub systemd-run
}

@test "awake-toggle: starts the inhibitor when it is off" {
    awake_stubs 3
    sut "$BIN/awake-toggle"
    assert_status 0
    assert_call_like "systemd-run --user --unit=awake-inhibit --collect systemd-inhibit --what=idle:sleep:handle-lid-switch"
    [[ "$(<"$XDG_RUNTIME_DIR/awake_inhibit.pid")" == 4242 ]]
    assert_call "qs ipc call quicksettings refresh"
}

@test "awake-toggle: stops the inhibitor when it is on" {
    awake_stubs 0
    echo 4242 >"$XDG_RUNTIME_DIR/awake_inhibit.pid"
    sut "$BIN/awake-toggle"
    assert_status 0
    assert_call "systemctl --user stop awake-inhibit.service"
    refute_call_like "systemd-run"
    [[ ! -e "$XDG_RUNTIME_DIR/awake_inhibit.pid" ]]
    assert_call "qs ipc call quicksettings refresh"
}

# --- quickshell-session ------------------------------------------------------

@test "quickshell-session: does nothing when quickshell already runs" {
    stub pidof 'exit 0'
    stub systemd-cat
    sut "$BIN/quickshell-session"
    assert_status 0
    refute_call_like "systemd-cat"
}

@test "quickshell-session: starts quickshell through mesa-egl and stops after a clean exit" {
    stub pidof 'exit 1'
    stub systemd-cat 'exit 0'
    sut "$BIN/quickshell-session"
    assert_status 0
    assert_call "systemd-cat -t quickshell -- $BIN/mesa-egl quickshell --no-duplicate"
    [[ "$(call_count systemd-cat)" -eq 1 ]]
}

@test "quickshell-session: relaunches a crashed shell, then gives up" {
    stub pidof 'exit 1'
    stub systemd-cat 'exit 1'
    stub hyprctl 'exit 0'
    stub logger
    sut "$BIN/quickshell-session"
    assert_status 1
    [[ "$(call_count systemd-cat)" -eq 6 ]]
    [[ "$(call_count "quickshell died, relaunching")" -eq 5 ]]
    assert_call_like "giving up after 6 relaunches"
}

@test "quickshell-session: does not relaunch while the session is going down" {
    stub pidof 'exit 1'
    stub systemd-cat 'exit 1'
    stub hyprctl 'exit 1'
    stub logger
    sut "$BIN/quickshell-session"
    assert_status 0
    [[ "$(call_count systemd-cat)" -eq 1 ]]
}
