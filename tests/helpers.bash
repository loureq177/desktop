# shellcheck shell=bash
# Shared bats helpers. Every script under test runs in a sandbox:
#   - $HOME and the XDG dirs point into the test's temp dir,
#   - PATH holds only stubs plus a whitelist of harmless tools, so a script can
#     never reach the real qs/hyprctl/wpctl/nmcli/sudo/pacman of this machine.
# A command that is neither stubbed nor whitelisted fails with "not found",
# which makes the test fail instead of touching the live session.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

SAFE_TOOLS=(
    bash sh env cat sed awk grep head tail cut tr sort uniq date mktemp mkdir rm rmdir cp mv ln ls
    touch chmod stat basename dirname readlink realpath find seq flock timeout jq tac id uname wc
    tee install cmp diff python3 zsh df numfmt xargs sqlite3 stow git lua true false printf test
    tar perl nproc
)

sandbox_setup() {
    SANDBOX="$BATS_TEST_TMPDIR"
    STUBS="$SANDBOX/stubs"
    SAFE="$SANDBOX/safe"
    CALLS="$SANDBOX/calls.log"
    REAL_SLEEP="$(command -v sleep)"
    REAL_DATE="$(command -v date)"

    export HOME="$SANDBOX/home"
    export XDG_RUNTIME_DIR="$SANDBOX/run"
    unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_DATA_HOME WALL_DIR TMPDIR
    mkdir -p "$HOME/.config" "$XDG_RUNTIME_DIR" "$STUBS" "$SAFE"
    : >"$CALLS"

    # What stow would give the scripts, but as copies: nothing writes to the repo.
    cp -r "$REPO/archlinux/.local" "$HOME/.local"
    cp -r "$REPO/common/.local/." "$HOME/.local"
    cp -r "$REPO/archlinux/.config/ui" "$HOME/.config/ui"

    local tool path
    for tool in "${SAFE_TOOLS[@]}"; do
        path="$(command -v "$tool" 2>/dev/null)" || continue
        [[ "$path" == /* ]] && ln -s "$path" "$SAFE/$tool"
    done
    SUT_PATH="$STUBS:$SAFE"
    BIN="$HOME/.local/bin"

    # Scripts sleep to debounce; tests do not need to wait for that.
    stub_quiet sleep "exec '$REAL_SLEEP' 0.01"
}

# stub NAME [BODY]: fake command that appends "NAME args..." to $CALLS and then
# runs BODY (bash, sees the original "$@").
stub() {
    local name=$1 body=${2:-}
    cat >"$STUBS/$name" <<EOF
#!/bin/bash
printf '%s\n' "$name \$*" >>"$CALLS"
$body
EOF
    chmod +x "$STUBS/$name"
}

# Like stub, but leaves no trace in $CALLS.
stub_quiet() {
    local name=$1 body=${2:-}
    printf '#!/bin/bash\n%s\n' "$body" >"$STUBS/$name"
    chmod +x "$STUBS/$name"
}

# stub_stdin NAME [BODY]: like stub, and also saves what the command received
# on stdin to $SANDBOX/NAME.stdin (appended, one blob per call).
stub_stdin() {
    local name=$1 body=${2:-}
    stub "$name" "cat >>'$SANDBOX/$name.stdin'
$body"
}

# A stand-in for a daemon-like program: logs the call and stays alive.
stub_longrunning() {
    stub "$1" "exec '$REAL_SLEEP' ${2:-20} >/dev/null 2>&1"
}

# Freeze the clock that `date` reports. fake_time HH MM [YYYY-mm-dd_HH-MM-SS]
fake_time() {
    stub_quiet date "
case \"\$1\" in
+%H) echo '$1' ;;
+%M) echo '$2' ;;
+%s) echo '${4:-1700000000}' ;;
+%Y-%m-%d_%H-%M-%S) echo '${3:-2026-01-02_03-04-05}' ;;
*) exec '$REAL_DATE' \"\$@\" ;;
esac"
}

# sut CMD ARGS...: run a command inside the sandbox (bats `run` semantics).
# fd 3 is closed so detached children cannot keep bats waiting.
sut() {
    run env PATH="$SUT_PATH" "$@" 3>&-
}

calls() { cat "$CALLS"; }

fail() {
    printf '%s\n' "$@" >&2
    return 1
}

# Exact-line match against the call log.
assert_call() {
    grep -qxF -- "$1" "$CALLS" || fail "expected call: $1" "--- calls:" "$(calls)" "--- output:" "${output:-}"
}

# Substring match against the call log.
assert_call_like() {
    grep -qF -- "$1" "$CALLS" || fail "expected a call containing: $1" "--- calls:" "$(calls)" "--- output:" "${output:-}"
}

refute_call_like() {
    if grep -qF -- "$1" "$CALLS"; then
        fail "unexpected call containing: $1" "--- calls:" "$(calls)"
    fi
}

call_count() { grep -cF -- "$1" "$CALLS" || true; }

# Detached helpers finish after the script returns; poll for their call.
wait_for_call_like() {
    local _
    for _ in $(seq 1 100); do
        grep -qF -- "$1" "$CALLS" && return 0
        "$REAL_SLEEP" 0.05
    done
    fail "timed out waiting for a call containing: $1" "--- calls:" "$(calls)"
}

assert_status() {
    [[ "$status" -eq "$1" ]] || fail "expected exit $1, got $status" "--- output:" "$output"
}

assert_output_like() {
    [[ "$output" == *"$1"* ]] || fail "expected output containing: $1" "--- output:" "$output"
}

need() {
    local tool
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 || skip "needs $tool"
    done
}

# Files of the working tree: tracked plus new-but-not-ignored, existing only.
repo_files() {
    local f
    git -C "$REPO" ls-files -co --exclude-standard -- "$@" | while IFS= read -r f; do
        [[ -f "$REPO/$f" ]] && printf '%s\n' "$f"
    done
}

# Copy the working tree (without ignored files) to DEST.
copy_repo() {
    mkdir -p "$1"
    (cd "$REPO" && repo_files | tar -cf - -T -) | tar -xf - -C "$1"
}
