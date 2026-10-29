# shellcheck shell=bash
# What the repo's scripts share: status lines, quiet runs, colours on a terminal.

# The ui.toml palette (ui.sh, from apply-ui) where there is one, else the
# terminal's own colours.
_ui_rgb() { printf '\033[38;2;%d;%d;%dm' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }
if [[ -t 1 ]]; then
    _ui_sh="${XDG_CONFIG_HOME:-$HOME/.config}/ui/ui.sh"
    # shellcheck source=/dev/null
    [[ -r "$_ui_sh" ]] && source "$_ui_sh"
    if [[ -n "${UI_ACCENT_BLUE:-}" ]]; then
        _C_BLUE=$(_ui_rgb "$UI_ACCENT_BLUE") _C_PURPLE=$(_ui_rgb "$UI_ACCENT_PURPLE")
        _C_GREEN=$(_ui_rgb "$UI_ACCENT_GREEN") _C_RED=$(_ui_rgb "$UI_CRITICAL")
        _C_YELLOW=$(_ui_rgb "${UI_WARNING:-d29922}") _C_DIM=$(_ui_rgb "$UI_TEXT_DIM")
    else
        _C_BLUE=$'\033[0;34m' _C_PURPLE=$'\033[0;35m' _C_GREEN=$'\033[0;32m'
        _C_RED=$'\033[0;31m' _C_YELLOW=$'\033[0;33m' _C_DIM=$'\033[2m'
    fi
    _C_BOLD=$'\033[1m' _C_NC=$'\033[0m'
else
    _C_BLUE="" _C_PURPLE="" _C_GREEN="" _C_YELLOW="" _C_RED="" _C_DIM="" _C_BOLD="" _C_NC=""
fi

# A section's heading, then its lines under it.
_log_info() { printf '\n%s●%s %s%s%s\n' "$_C_BLUE" "$_C_NC" "$_C_BOLD" "$*" "$_C_NC"; }
_log_ok() { printf '  %s✓%s %s\n' "$_C_GREEN" "$_C_NC" "$*"; }
_log_warn() { printf '  %s⚠%s %s\n' "$_C_YELLOW" "$_C_NC" "$*"; }
_log_error() { printf '  %s✗%s %s\n' "$_C_RED" "$_C_NC" "$*" >&2; }

# The last line of sysclean: how much disk space came back, in how long.
_log_total() {
    printf '\n%s%s✓ %s freed · %s%s\n' "$_C_GREEN" "$_C_BOLD" "$1" "$2" "$_C_NC"
}

# _join SEP ITEM...: the items with SEP between them.
_join() {
    local sep=$1 out="" x
    shift
    for x in "$@"; do
        out+=${out:+$sep}$x
    done
    printf '%s' "$out"
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

# run_if TOOL CMD...: runs CMD when TOOL is installed, output dropped, for two
# minutes at most.
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
