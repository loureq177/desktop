#!/usr/bin/env bats
# wallpaper, check-updates, awake-toggle,
# quickshell-session

load helpers

setup() {
    sandbox_setup
    stub qs
    stub notify-send
    WALLS="$HOME/Pictures/Wallpapers"
    WALL_STATE="$HOME/.cache/wallpaper/current"
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

# --- check-updates -----------------------------------------------------------

CU_STAMP() { echo "$HOME/.local/state/check-updates/last-check"; }

updates_stubs() {
    # $1 official lines, $2 checkupdates exit, $3 aur lines, $4 pacnew lines
    stub checkupdates "printf '%s' '$1'; exit $2"
    stub paru "printf '%s' '$3'"
    stub pacdiff "printf '%s' '$4'"
}

@test "check-updates: notifies with the official and AUR counts" {
    updates_stubs $'a 1 -> 2\nb 1 -> 2\nc 1 -> 2\n' 0 $'x 1 -> 2\ny 1 -> 2\n' ''
    sut "$BIN/check-updates"
    assert_status 0
    assert_call_like "Available updates (5)"
    assert_call_like "Official packages: 3"
    assert_call_like "AUR packages: 2"
    assert_call_like "-A update=Update system"
    refute_call_like "ghostty"
    [[ "$(<"$(CU_STAMP)")" =~ ^[0-9]+$ ]]
}

@test "check-updates: the notification's button starts the upgrade" {
    updates_stubs $'a 1 -> 2\n' 0 '' ''
    stub notify-send 'echo update'
    stub ghostty
    sut "$BIN/check-updates"
    assert_status 0
    assert_call "ghostty +new-window -e $HOME/.local/bin/sysupdate"
}

@test "check-updates: stays quiet when everything is up to date" {
    updates_stubs '' 2 '' ''
    sut "$BIN/check-updates"
    assert_status 0
    refute_call_like "notify-send"
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
    refute_call_like "notify-send"
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
    refute_call_like "notify-send"
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
}

@test "awake-toggle: stops the inhibitor when it is on" {
    awake_stubs 0
    echo 4242 >"$XDG_RUNTIME_DIR/awake_inhibit.pid"
    sut "$BIN/awake-toggle"
    assert_status 0
    assert_call "systemctl --user stop awake-inhibit.service"
    refute_call_like "systemd-run"
    [[ ! -e "$XDG_RUNTIME_DIR/awake_inhibit.pid" ]]
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

lock_state() {
    export HYPRLAND_INSTANCE_SIGNATURE=sig
    LOCK_STATE="$XDG_RUNTIME_DIR/hypr/sig/quickshell-lock-state"
    mkdir -p "${LOCK_STATE%/*}"
    [[ -z "${1:-}" ]] || echo "$1" >"$LOCK_STATE"
}

@test "quickshell-session: a shell that dies before unlocking leaves the session to hyprlock" {
    stub pidof 'exit 1'
    stub systemd-cat 'exit 1'
    stub hyprctl 'exit 0'
    stub logger
    stub hyprlock
    lock_state locked
    sut "$BIN/quickshell-session"
    # Unlocked through hyprlock once; the relaunches after that do not lock again.
    [[ "$(grep -cx "hyprlock " "$CALLS")" -eq 1 ]] || fail "$(calls)"
    [[ "$(<"$LOCK_STATE")" == unlocked ]]
}

@test "quickshell-session: locks with hyprlock when the shell never came up at all" {
    stub pidof 'exit 1'
    stub systemd-cat 'exit 1'
    stub hyprctl 'exit 0'
    stub logger
    stub hyprlock 'exit 1'
    lock_state
    sut "$BIN/quickshell-session"
    assert_status 1
    assert_call "hyprlock "
    assert_call_like "THE SESSION IS NOT LOCKED"
    [[ ! -e "$LOCK_STATE" ]]
}

@test "quickshell-session: a crash in an unlocked session does not lock it" {
    stub pidof 'exit 1'
    stub systemd-cat 'exit 1'
    stub hyprctl 'exit 0'
    stub logger
    stub hyprlock
    lock_state unlocked
    sut "$BIN/quickshell-session"
    refute_call_like "hyprlock"
}

@test "quickshell-session: relaunches a crashed shell, then gives up" {
    stub pidof 'exit 1'
    stub systemd-cat 'exit 1'
    stub hyprctl 'exit 0'
    stub logger
    stub hyprlock
    lock_state unlocked
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
