# shellcheck shell=bash
# Shared status lines for sysupdate and sysclean, same names as install.sh.
# Source, don't execute. Colours only when stdout is a terminal.

if [[ -t 1 ]]; then
    _C_BLUE=$'\033[0;34m' _C_GREEN=$'\033[0;32m' _C_YELLOW=$'\033[0;33m' _C_RED=$'\033[0;31m' _C_NC=$'\033[0m'
else
    _C_BLUE="" _C_GREEN="" _C_YELLOW="" _C_RED="" _C_NC=""
fi

_log_info() { printf '\n%s==>%s %s\n' "$_C_BLUE" "$_C_NC" "$*"; }
_log_ok() { printf '%s✓%s %s\n' "$_C_GREEN" "$_C_NC" "$*"; }
_log_warn() { printf '%s⚠%s  %s\n' "$_C_YELLOW" "$_C_NC" "$*"; }
_log_error() { printf '%s✗%s %s\n' "$_C_RED" "$_C_NC" "$*" >&2; }

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
