#!/usr/bin/env bats
# brightness, restore-backlight, clipboard-insert, emoji-insert, dictation

load helpers

setup() {
    sandbox_setup
    stub qs
}

teardown() {
    [[ ! -f "$XDG_RUNTIME_DIR/dictation.pid" ]] || kill "$(<"$XDG_RUNTIME_DIR/dictation.pid")" 2>/dev/null || true
}

# --- brightness --------------------------------------------------------------

backlight() {
    # $1: csv line printed for `brightnessctl -c backlight -m`
    stub brightnessctl "[[ \"\$*\" == '-c backlight -m' ]] && printf '%s' '$1'; true"
}

@test "brightness up/down: steps by 10% and shows the OSD" {
    backlight $'amdgpu_bl1,backlight,128,50%,255\n'
    sut "$BIN/brightness" up
    assert_status 0
    assert_call "brightnessctl -c backlight set +10%"
    assert_call "qs ipc call osd brightness 50"

    sut "$BIN/brightness" down
    assert_status 0
    assert_call "brightnessctl -c backlight set 10%-"
}

@test "brightness: rejects anything but up and down" {
    backlight $'amdgpu_bl1,backlight,128,50%,255\n'
    sut "$BIN/brightness" sideways
    assert_status 2
    refute_call_like " set "
}

@test "brightness: is a no-op on machines without a backlight" {
    backlight ''
    sut "$BIN/brightness" up
    assert_status 0
    refute_call_like " set "
    refute_call_like "qs ipc"
}

@test "brightness: is a no-op without brightnessctl" {
    sut "$BIN/brightness" up
    assert_status 0
    refute_call_like "qs ipc"
}

# --- restore-backlight -------------------------------------------------------

@test "restore-backlight: nudges the level down and back, twice" {
    stub brightnessctl '[[ "$*" == *get* ]] && echo 100; true'
    sut "$BIN/restore-backlight"
    assert_status 0
    [[ "$(call_count "brightnessctl -q -c backlight set 99")" -eq 2 ]] || fail "$(calls)"
    [[ "$(call_count "brightnessctl -q -c backlight set 100")" -eq 2 ]] || fail "$(calls)"
}

@test "restore-backlight: nudges upwards from zero" {
    stub brightnessctl '[[ "$*" == *get* ]] && echo 0; true'
    sut "$BIN/restore-backlight"
    assert_status 0
    assert_call "brightnessctl -q -c backlight set 1"
    assert_call "brightnessctl -q -c backlight set 0"
}

# --- clipboard-insert / emoji-insert ----------------------------------------

clipboard_stubs() {
    stub cliphist 'printf "from history"'
    stub_stdin wl-copy
    stub wtype
    mkdir -p "$SANDBOX/tmp"
}

@test "clipboard-insert: copies the history entry and pastes it" {
    clipboard_stubs
    TMPDIR="$SANDBOX/tmp" sut "$BIN/clipboard-insert" 42
    assert_status 0
    assert_call "cliphist decode 42"
    assert_call "wl-copy "
    [[ "$(<"$SANDBOX/wl-copy.stdin")" == "from history" ]]
    assert_call "wtype -M shift -k Insert -m shift"
    [[ -z "$(ls -A "$SANDBOX/tmp")" ]] || fail "temp file left behind: $(ls -A "$SANDBOX/tmp")"
}

@test "clipboard-insert: passes the mime type for images" {
    clipboard_stubs
    TMPDIR="$SANDBOX/tmp" sut "$BIN/clipboard-insert" 7 image/png
    assert_status 0
    assert_call "wl-copy --type image/png"
}

@test "clipboard-insert: does nothing without an id or when the entry is gone" {
    clipboard_stubs
    TMPDIR="$SANDBOX/tmp" sut "$BIN/clipboard-insert"
    assert_status 0
    refute_call_like "cliphist"

    stub cliphist 'exit 1'
    TMPDIR="$SANDBOX/tmp" sut "$BIN/clipboard-insert" 42
    assert_status 0
    refute_call_like "wl-copy"
    refute_call_like "wtype"
    [[ -z "$(ls -A "$SANDBOX/tmp")" ]] || fail "temp file left behind: $(ls -A "$SANDBOX/tmp")"
}

@test "emoji-insert: types the emoji, and nothing when called empty" {
    stub wtype
    sut "$BIN/emoji-insert"
    assert_status 0
    refute_call_like "wtype"

    sut "$BIN/emoji-insert" "😀"
    assert_status 0
    assert_call "wtype -- 😀"
}

# --- dictation ---------------------------------------------------------------

dictation_stubs() {
    # $1: keyboard layout reported by Hyprland, $2: what whisper transcribes
    stub hyprctl "printf 'str: %s\nset: true\n' '$1'"
    stub_longrunning pw-record
    stub sox 'cp "$1" "$2"'
    stub whisper-cli "printf '%s\n' '$2'"
    stub_stdin wl-copy
    stub wtype
    stub notify-send
    mkdir -p "$HOME/.local/share/whisper"
    echo model >"$HOME/.local/share/whisper/ggml-base.bin"
}

@test "dictation: says so instead of recording when the speech model is missing" {
    dictation_stubs pl ""
    rm "$HOME/.local/share/whisper/ggml-base.bin"
    sut "$BIN/dictation"
    assert_status 1
    assert_call_like "Speech model not found"
    refute_call_like "pw-record"
}

recorded_audio() {
    head -c "$1" /dev/zero >"$XDG_RUNTIME_DIR/dictation_raw.wav"
    echo 999999999 >"$XDG_RUNTIME_DIR/dictation.pid"
}

@test "dictation: the first press starts recording" {
    dictation_stubs pl ""
    sut "$BIN/dictation"
    assert_status 0
    assert_call "qs ipc call dictation start"
    assert_call "pw-record --rate 16000 --channels 1 $XDG_RUNTIME_DIR/dictation_raw.wav"
    kill -0 "$(<"$XDG_RUNTIME_DIR/dictation.pid")"
}

@test "dictation: the second press transcribes, copies and pastes the text" {
    dictation_stubs pl " Dzień dobry. "
    recorded_audio 16000
    sut "$BIN/dictation"
    assert_status 0
    assert_call "qs ipc call dictation transcribing"
    assert_call_like "whisper-cli -m $HOME/.local/share/whisper/ggml-base.bin"
    assert_call_like "-l pl"
    [[ "$(<"$SANDBOX/wl-copy.stdin")" == "Dzień dobry. " ]] || fail "copied: '$(<"$SANDBOX/wl-copy.stdin")'"
    assert_call "wtype -M shift -k Insert -m shift"
    assert_call "qs ipc call dictation stop"
    [[ ! -e "$XDG_RUNTIME_DIR/dictation.pid" && ! -e "$XDG_RUNTIME_DIR/dictation_raw.wav" && ! -e "$XDG_RUNTIME_DIR/dictation_clean.wav" ]]
}

@test "dictation: picks the whisper language from the keyboard layout" {
    local layout want
    while read -r layout want; do
        : >"$CALLS"
        dictation_stubs "$layout" "text"
        recorded_audio 16000
        sut "$BIN/dictation"
        assert_status 0
        assert_call_like "-l $want"
    done <<'EOF'
us en
pl pl
de de
pl,us pl
us,pl en
weird-layout-123 pl
EOF
}

@test "dictation: falls back to Polish when Hyprland does not answer" {
    dictation_stubs pl "text"
    stub hyprctl 'exit 1'
    recorded_audio 16000
    sut "$BIN/dictation"
    assert_status 0
    assert_call_like "-l pl"
}

@test "dictation: pastes nothing for silence markers or too-short recordings" {
    local text
    for text in "[BLANK_AUDIO]" "(music)" ""; do
        : >"$CALLS"
        dictation_stubs pl "$text"
        recorded_audio 16000
        sut "$BIN/dictation"
        assert_status 0
        refute_call_like "wl-copy"
        refute_call_like "wtype"
        assert_call "qs ipc call dictation stop"
    done

    : >"$CALLS"
    dictation_stubs pl "should not be used"
    recorded_audio 100
    sut "$BIN/dictation"
    assert_status 0
    refute_call_like "whisper-cli"
    assert_call "qs ipc call dictation stop"
    [[ ! -e "$XDG_RUNTIME_DIR/dictation_raw.wav" ]]
}

@test "dictation stop: only stops, never starts a recording" {
    dictation_stubs pl ""
    sut "$BIN/dictation" stop
    assert_status 0
    refute_call_like "pw-record"
    assert_call "qs ipc call dictation stop"
}

@test "dictation: still transcribes when sox is unavailable" {
    dictation_stubs pl "ok"
    stub sox 'exit 1'
    recorded_audio 16000
    sut "$BIN/dictation"
    assert_status 0
    [[ "$(<"$SANDBOX/wl-copy.stdin")" == "ok " ]]
}
