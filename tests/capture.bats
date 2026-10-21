#!/usr/bin/env bats
# screenshot, ocr, record-screen and the capture.sh helpers they share

load helpers

setup() {
    sandbox_setup
    fake_time 03 04 2026-01-02_03-04-05
    SHOTS="$HOME/Pictures/Screenshots"
    CASTS="$HOME/Videos/Screencasts"
    STATUS_FILE="$XDG_RUNTIME_DIR/recording_status"
    DND_MARKER="$XDG_RUNTIME_DIR/recording_dnd"
    MODULES_FILE="$XDG_RUNTIME_DIR/recording_audio_modules"

    echo '[]' >"$SANDBOX/monitors.json"
    echo '[]' >"$SANDBOX/clients.json"
    stub hyprctl "
case \"\$1\" in
monitors) cat '$SANDBOX/monitors.json' ;;
clients) cat '$SANDBOX/clients.json' ;;
esac"
    stub_longrunning hyprpicker
    stub grim 'echo PNGDATA >"${@: -1}"'
    stub_stdin wl-copy
    stub notify-send
    stub canberra-gtk-play
    stub satty
    stub qs "[[ \"\$*\" == *'notifications dndOn'* ]] && echo true; true"
    stub pkill 'exit 1'
    stub pgrep 'exit 1'
    stub wf-recorder "echo \$\$ >'$SANDBOX/wf.pid'; exec '$REAL_SLEEP' 20 >/dev/null 2>&1"
    stub v4l2-ctl
    stub pactl "
case \"\$1\" in
get-default-sink) echo alsa_out ;;
get-default-source) echo alsa_in ;;
load-module) n=\$(( \$(cat '$SANDBOX/modules' 2>/dev/null || echo 40) + 1 )); echo \$n >'$SANDBOX/modules'; echo \$n ;;
esac"
    selection "100,100 800x600"
}

teardown() {
    local f
    for f in "$SANDBOX/wf.pid" "$XDG_RUNTIME_DIR/recording_webcam.pid"; do
        [[ ! -f "$f" ]] || kill "$(<"$f")" 2>/dev/null || true
    done
}

# selection GEOM | selection cancel: what the user picks in slurp.
selection() {
    if [[ "$1" == cancel ]]; then
        stub_stdin slurp 'exit 1'
    else
        stub_stdin slurp "echo '$1'"
    fi
}

# --- capture.sh --------------------------------------------------------------

@test "capture: slurp gets the themed arguments from ui.sh" {
    sut "$BIN/screenshot" region
    assert_status 0
    # shellcheck disable=SC1091
    source "$HOME/.config/ui/ui.sh"
    assert_call "slurp ${SLURP_ARGS[*]}"
}

@test "capture: offers only the windows that are actually visible" {
    cat >"$SANDBOX/monitors.json" <<'EOF'
[{"name":"DP-1","focused":true,"activeWorkspace":{"id":1},"specialWorkspace":{"id":0}},
 {"name":"eDP-1","focused":false,"activeWorkspace":{"id":3},"specialWorkspace":{"id":-98}}]
EOF
    cat >"$SANDBOX/clients.json" <<'EOF'
[{"at":[0,0],"size":[100,100],"workspace":{"id":1},"mapped":true,"hidden":false,"fullscreen":0,"floating":false},
 {"at":[1,1],"size":[11,11],"workspace":{"id":2},"mapped":true,"hidden":false,"fullscreen":0,"floating":false},
 {"at":[2,2],"size":[22,22],"workspace":{"id":3},"mapped":true,"hidden":false,"fullscreen":0,"floating":false},
 {"at":[3,3],"size":[33,33],"workspace":{"id":1},"mapped":true,"hidden":true,"fullscreen":0,"floating":false},
 {"at":[4,4],"size":[44,44],"workspace":{"id":1},"mapped":false,"hidden":false,"fullscreen":0,"floating":false},
 {"at":[500,500],"size":[300,200],"workspace":{"id":-98},"mapped":true,"hidden":false,"fullscreen":2,"floating":false},
 {"at":[5,5],"size":[55,55],"workspace":{"id":-98},"mapped":true,"hidden":false,"fullscreen":0,"floating":false},
 {"at":[10,10],"size":[50,50],"workspace":{"id":-98},"mapped":true,"hidden":false,"fullscreen":0,"floating":true}]
EOF
    sut "$BIN/screenshot" region
    assert_status 0
    # ws 1 window, the fullscreen one on the special workspace, the floating one above it
    [[ "$(<"$SANDBOX/slurp.stdin")" == $'0,0 100x100\n500,500 300x200\n10,10 50x50' ]] ||
        fail "rects given to slurp:" "$(<"$SANDBOX/slurp.stdin")"
}

@test "capture: still lets you select when Hyprland gives no window list" {
    stub hyprctl 'exit 1'
    sut "$BIN/screenshot" region
    assert_status 0
    assert_call_like "grim -g 100,100 800x600"
}

# --- screenshot --------------------------------------------------------------

@test "screenshot region: saves the selection, copies it and notifies" {
    sut "$BIN/screenshot" region
    assert_status 0
    assert_call "hyprpicker -r -z"
    assert_call "grim -g 100,100 800x600 $SHOTS/2026-01-02_03-04-05.png"
    assert_call "wl-copy -t image/png"
    [[ "$(<"$SANDBOX/wl-copy.stdin")" == PNGDATA ]]
    assert_call_like "canberra-gtk-play -i camera-shutter"
    assert_call_like "notify-send --app-name Screenshot"
    refute_call_like "satty"
}

@test "screenshot: region is the default mode" {
    sut "$BIN/screenshot"
    assert_status 0
    assert_call_like "grim -g 100,100 800x600"
}

@test "screenshot region: cancelling takes no screenshot" {
    selection cancel
    sut "$BIN/screenshot" region
    assert_status 0
    refute_call_like "grim"
    refute_call_like "notify-send"
}

@test "screenshot region: a stray click takes no screenshot" {
    selection "640,360 1x1"
    sut "$BIN/screenshot" region
    assert_status 0
    refute_call_like "grim"
}

@test "screenshot region: slurp offers each monitor, so a click on no window takes it" {
    echo '[{"name":"eDP-1","x":0,"y":0,"width":2880,"height":1800,"scale":1.5,"transform":0},
           {"name":"DP-1","x":1920,"y":0,"width":1080,"height":1920,"scale":1,"transform":1}]' >"$SANDBOX/monitors.json"
    selection "0,0 1920x1200"
    sut "$BIN/screenshot" region
    assert_status 0
    grep -qx "0,0 1920x1200" "$SANDBOX/slurp.stdin"
    grep -qx "1920,0 1920x1080" "$SANDBOX/slurp.stdin"
    assert_call "grim -g 0,0 1920x1200 $SHOTS/2026-01-02_03-04-05.png"
}
@test "screenshot fullscreen: captures the focused monitor" {
    echo '[{"name":"eDP-1","focused":false},{"name":"DP-1","focused":true}]' >"$SANDBOX/monitors.json"
    sut "$BIN/screenshot" fullscreen
    assert_status 0
    assert_call "grim -o DP-1 $SHOTS/2026-01-02_03-04-05.png"
    refute_call_like "slurp"
}

@test "screenshot fullscreen: captures everything when the focused monitor is unknown" {
    stub hyprctl 'exit 1'
    sut "$BIN/screenshot" fullscreen
    assert_status 0
    assert_call "grim $SHOTS/2026-01-02_03-04-05.png"
}

@test "screenshot: the notification's Edit action opens satty on the file" {
    stub notify-send 'echo default'
    sut "$BIN/screenshot" region
    assert_status 0
    local file="$SHOTS/2026-01-02_03-04-05.png"
    assert_call "satty --filename $file --fullscreen --output-filename $file"
}

@test "screenshot: two shots in the same second do not overwrite each other" {
    sut "$BIN/screenshot" fullscreen
    sut "$BIN/screenshot" fullscreen
    sut "$BIN/screenshot" fullscreen
    assert_status 0
    [[ -f "$SHOTS/2026-01-02_03-04-05.png" && -f "$SHOTS/2026-01-02_03-04-05-1.png" && -f "$SHOTS/2026-01-02_03-04-05-2.png" ]] ||
        fail "$(ls "$SHOTS")"
}

@test "screenshot: rejects an unknown mode" {
    sut "$BIN/screenshot" window
    assert_status 2
    refute_call_like "grim"
}

@test "screenshot: a second instance exits while one is selecting" {
    exec 9>"$XDG_RUNTIME_DIR/screenshot_slurp.lock"
    flock -n 9
    sut "$BIN/screenshot" region
    exec 9>&-
    assert_status 0
    refute_call_like "slurp"
}

@test "screenshot: reports nothing when grim produced no file" {
    stub grim 'exit 1'
    sut "$BIN/screenshot" region
    refute_call_like "notify-send"
    refute_call_like "wl-copy"
}

# --- ocr ---------------------------------------------------------------------

@test "ocr: copies the recognised text and shows a preview" {
    stub tesseract 'printf "  Zażółć gęślą\njaźń  \n"'
    sut "$BIN/ocr"
    assert_status 0
    assert_call "hyprpicker -r -z"
    assert_call_like "tesseract $XDG_RUNTIME_DIR/ocr."
    assert_call_like "stdout -l pol+eng"
    [[ "$(<"$SANDBOX/wl-copy.stdin")" == $'Zażółć gęślą\njaźń' ]] || fail "copied: '$(<"$SANDBOX/wl-copy.stdin")'"
    assert_call_like 'Text copied to clipboard:\nZażółć gęślą'
}

@test "ocr: shortens long text in the notification, not in the clipboard" {
    local long
    long="$(printf 'a%.0s' {1..150})"
    stub tesseract "printf '%s' '$long'"
    sut "$BIN/ocr"
    assert_status 0
    [[ "$(<"$SANDBOX/wl-copy.stdin")" == "$long" ]]
    assert_call_like "clipboard:\\n${long:0:100}..."
    refute_call_like "${long:0:101}"
}

@test "ocr: warns when no text was recognised" {
    stub tesseract 'printf "  \n"'
    sut "$BIN/ocr"
    assert_status 0
    refute_call_like "wl-copy"
    assert_call_like "No text recognized."
    assert_call_like "canberra-gtk-play -i dialog-warning"
}

@test "ocr: cancelling does nothing and leaves no temp files" {
    stub tesseract
    selection cancel
    sut "$BIN/ocr"
    assert_status 0
    refute_call_like "grim"
    refute_call_like "tesseract"
    refute_call_like "notify-send"
    [[ -z "$(find "$XDG_RUNTIME_DIR" -name 'ocr.*')" ]]
}

@test "ocr: removes its temp files afterwards" {
    stub tesseract 'echo text'
    sut "$BIN/ocr"
    assert_status 0
    [[ -z "$(find "$XDG_RUNTIME_DIR" -name 'ocr.*')" ]] || fail "$(find "$XDG_RUNTIME_DIR")"
}

# --- record-screen -----------------------------------------------------------

@test "record-screen: records the selection with desktop audio" {
    sut "$BIN/record-screen"
    assert_status 0
    local file="$CASTS/2026-01-02_03-04-05.mp4"
    assert_call "wf-recorder -c libx264 -x yuv420p -C aac --audio=alsa_out.monitor -g 100,100 800x600 -f $file"
    [[ "$(<"$STATUS_FILE")" == "$file" ]]
    kill -0 "$(<"$SANDBOX/wf.pid")"
}

@test "record-screen: silences notifications and remembers to restore them" {
    sut "$BIN/record-screen"
    assert_status 0
    assert_call "qs ipc call notifications dndOn"
    [[ -f "$DND_MARKER" ]]
}

@test "record-screen: leaves do-not-disturb alone when it was already on" {
    stub qs "[[ \"\$*\" == *'notifications dndOn'* ]] && echo false; true"
    sut "$BIN/record-screen"
    assert_status 0
    assert_call "qs ipc call notifications dndOn"
    [[ ! -e "$DND_MARKER" ]]
}

@test "record-screen: records without audio when there is no sink" {
    stub pactl 'exit 1'
    sut "$BIN/record-screen"
    assert_status 0
    assert_call "wf-recorder -c libx264 -x yuv420p -g 100,100 800x600 -f $CASTS/2026-01-02_03-04-05.mp4"
}

@test "record-screen --mic: mixes desktop and microphone into one device" {
    sut "$BIN/record-screen" --mic
    assert_status 0
    assert_call_like "pactl load-module module-null-sink sink_name=record_mix"
    assert_call "pactl load-module module-loopback source=alsa_out.monitor sink=record_mix latency_msec=20"
    assert_call "pactl load-module module-loopback source=alsa_in sink=record_mix latency_msec=20"
    assert_call_like "--audio=record_mix.monitor"
    [[ "$(<"$MODULES_FILE")" == $'41\n42\n43' ]] || fail "$(<"$MODULES_FILE")"
}

@test "record-screen: cancelling or a stray click records nothing" {
    selection cancel
    sut "$BIN/record-screen"
    assert_status 0
    selection "5,5 1x1"
    sut "$BIN/record-screen"
    assert_status 0
    refute_call_like "wf-recorder -c"
    refute_call_like "dndOn"
    [[ ! -e "$STATUS_FILE" ]]
}

@test "record-screen: cleans up and reports when wf-recorder dies at once" {
    stub wf-recorder 'exit 1'
    stub_quiet sleep "exec '$REAL_SLEEP' 0.3"
    sut "$BIN/record-screen" --mic
    assert_status 1
    assert_call_like "Recording Failed"
    assert_call "qs ipc call notifications dndOff"
    assert_call "pactl unload-module 41"
    [[ ! -e "$STATUS_FILE" && ! -e "$DND_MARKER" && ! -e "$MODULES_FILE" ]]
}

@test "record-screen --cam: carries on without a camera" {
    sut "$BIN/record-screen" --cam
    assert_status 0
    assert_call_like "No Camera Found"
    assert_call_like "wf-recorder"
    refute_call_like "ffplay"
}

@test "record-screen --cam: parks the camera in the corner of the recorded area" {
    compgen -G "/dev/video*" >/dev/null || skip "no video device on this machine"
    stub v4l2-ctl "printf '\t[0]: MJPG (Motion-JPEG, compressed)\n'"
    stub_longrunning ffplay
    echo '[{"title":"WebcamOverlay","address":"0xabc"}]' >"$SANDBOX/clients.json"
    sut "$BIN/record-screen" --cam
    assert_status 0
    # 800 wide -> 160 would be too small, so the camera is 200x112, 24px from the corner.
    assert_call_like "-window_title WebcamOverlay -x 200 -y 112"
    assert_call 'hyprctl dispatch hl.dsp.window.resize({ window = "address:0xabc", x = 200, y = 112 })'
    assert_call 'hyprctl dispatch hl.dsp.window.move({ window = "address:0xabc", x = 676, y = 564 })'
    # The camera has to be in place before the recording starts.
    [[ "$(grep -n 'hl.dsp.window.move' "$CALLS" | cut -d: -f1)" -lt "$(grep -n '^wf-recorder' "$CALLS" | cut -d: -f1)" ]]
}

# recording_in_progress FILE: state left behind by a running recording.
recording_in_progress() {
    stub pkill 'exit 0'
    mkdir -p "$CASTS"
    echo "$1" >"$STATUS_FILE"
    : >"$DND_MARKER"
    printf '41\n42\n43\n' >"$MODULES_FILE"
}

@test "record-screen: the toggle stops a running recording and restores everything" {
    recording_in_progress "$CASTS/take.mp4"
    : >"$CASTS/take.mp4"
    sut "$BIN/record-screen"
    assert_status 0
    assert_call "pkill -INT -x wf-recorder"
    assert_call "qs ipc call notifications dndOff"
    assert_call_like "Recording saved to:\\n$CASTS/take.mp4"
    [[ ! -e "$STATUS_FILE" && ! -e "$DND_MARKER" && ! -e "$MODULES_FILE" ]]
    refute_call_like "slurp"
    # The loopbacks are unloaded before the null sink they feed.
    [[ "$(grep -F 'unload-module' "$CALLS" | tr '\n' ' ')" == "pactl unload-module 43 pactl unload-module 42 pactl unload-module 41 " ]] ||
        fail "$(calls)"
}

@test "record-screen stop: the notification's Play action opens the recording" {
    recording_in_progress "$CASTS/take.mp4"
    : >"$CASTS/take.mp4"
    stub notify-send 'echo default'
    stub xdg-open
    sut "$BIN/record-screen"
    assert_status 0
    wait_for_call_like "xdg-open $CASTS/take.mp4"
}

@test "record-screen stop: says so when the recording file is missing" {
    recording_in_progress "$CASTS/never-written.mp4"
    sut "$BIN/record-screen"
    assert_status 0
    assert_call_like "Recording stopped. No file found."
}

@test "record-screen: clears leftovers of a recording that died on its own" {
    echo "$CASTS/old.mp4" >"$STATUS_FILE"
    : >"$DND_MARKER"
    printf '41\n' >"$MODULES_FILE"
    selection cancel
    sut "$BIN/record-screen"
    assert_status 0
    assert_call "qs ipc call notifications dndOff"
    assert_call "pactl unload-module 41"
    [[ ! -e "$STATUS_FILE" && ! -e "$DND_MARKER" && ! -e "$MODULES_FILE" ]]
}
