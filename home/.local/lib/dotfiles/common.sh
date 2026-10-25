# shellcheck shell=bash
# What the scripts of this repo share: status lines, quiet runs, the way to
# root. install.sh, sysupdate and sysclean source it. Kept to bash 3.2,
# which is what macOS ships, for install.sh. Colours only when stdout is a terminal.

if [[ -t 1 ]]; then
    _C_BLUE=$'\033[0;34m' _C_GREEN=$'\033[0;32m' _C_YELLOW=$'\033[0;33m' _C_RED=$'\033[0;31m' _C_NC=$'\033[0m'
else
    _C_BLUE="" _C_GREEN="" _C_YELLOW="" _C_RED="" _C_NC=""
fi

_log_info() { printf '\n%s==>%s %s\n' "$_C_BLUE" "$_C_NC" "$*"; }
_log_ok() { printf '%s✓%s %s\n' "$_C_GREEN" "$_C_NC" "$*"; }
_log_warn() { printf '%s⚠%s  %s\n' "$_C_YELLOW" "$_C_NC" "$*"; }
_log_error() { printf '%s✗%s %s\n' "$_C_RED" "$_C_NC" "$*" >&2; }

# The last line of sysclean: how much disk space came back.
_log_total() {
    local line="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '\n%s%s\n  Total reclaimed space: %s\n%s%s\n' "$_C_GREEN" "$line" "$1" "$line" "$_C_NC"
}

# run_captured CMD...: run with output held back, stripped of colour codes, in
# $OUT (exit status in $RC). A failure prints the whole output and returns 1.
run_captured() {
    RC=0
    OUT=$("$@" 2>&1 </dev/null) || RC=$?
    OUT=$(printf '%s' "$OUT" | sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g')
    [ "$RC" -eq 0 ] && return 0
    [ -z "$OUT" ] || printf '%s\n' "$OUT"
    _log_error "Failed (exit $RC): $1"
    return 1
}

# run_if TOOL CMD...: run CMD when TOOL is installed, its output dropped. The
# cache cleaners report "0 bytes removed" even with nothing to do; the caller's
# own line says what was cleaned. Two minutes at most where `timeout` exists.
run_if() {
    command -v "$1" >/dev/null 2>&1 || return 0
    local tool=$1 rc=0
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout 120 "$@" </dev/null >/dev/null 2>&1 || rc=$?
    else
        "$@" </dev/null >/dev/null 2>&1 || rc=$?
    fi
    [ "$rc" -ne 124 ] || echo "  (skipped $tool - timed out)"
}

# What asks for root: the quickshell polkit dialog in the Hyprland session,
# sudo in a tty or over ssh, where there is no dialog and pkexec's own text
# agent fails on polkit 127 (polkit-org/polkit#686).
as_root() {
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        echo pkexec
    else
        echo sudo
    fi
}
