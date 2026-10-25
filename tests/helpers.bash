# shellcheck shell=bash
# Shared bats helpers.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

fail() {
    printf '%s\n' "$@" >&2
    return 1
}

assert_status() {
    [[ "$status" -eq "$1" ]] || fail "expected exit $1, got $status" "--- output:" "$output"
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
