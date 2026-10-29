# shellcheck shell=bash
# Steps run at once: `task LABEL FN` queues one, `task_start` starts it now, `run_tasks
# TITLE` runs the rest; a step's last line is its summary (⚠ warns), all in $TASKS_LOG.

TASKS_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tasks.XXXXXX")
TASKS_LOG=${TASKS_LOG:-}
TASKS_FAILED=0
_TASK_LABELS=()
_TASK_FUNCS=()
_TASK_PIDS=()
_TASK_TEXT=()
_TASK_KIND=()

# A step started ahead is let finish when the script stops short (pacman
# failed): Ctrl+C stops it with the rest.
_tasks_cleanup() {
    ((${#_TASK_PIDS[@]} == 0)) || wait "${_TASK_PIDS[@]}" 2>/dev/null || true
    rm -rf -- "$TASKS_DIR"
}
trap _tasks_cleanup EXIT

task() {
    _TASK_LABELS+=("$1")
    _TASK_FUNCS+=("$2")
}

task_start() {
    task "$@"
    _task_spawn $((${#_TASK_LABELS[@]} - 1))
}

# Microseconds since the epoch, without a fork.
_task_now() {
    printf '%s' "${EPOCHREALTIME/./}"
}

# The status file comes last: once it is there, the step is done.
_task_spawn() {
    local i=$1
    _task_now >"$TASKS_DIR/$i.start"
    (
        rc=0
        "${_TASK_FUNCS[$i]}" >"$TASKS_DIR/$i.out" 2>&1 </dev/null || rc=$?
        _task_now >"$TASKS_DIR/$i.end"
        echo "$rc" >"$TASKS_DIR/$i.rc"
    ) &
    _TASK_PIDS[i]=$!
}

# "0.4s", "12.3s", "2m 05s".
_task_time() {
    local ds=$(($1 / 100000))
    if ((ds < 600)); then
        printf '%d.%ds' $((ds / 10)) $((ds % 10))
    else
        printf '%dm %02ds' $((ds / 600)) $((ds / 10 % 60))
    fi
}

_task_elapsed() {
    local i=$1 start end
    start=$(<"$TASKS_DIR/$i.start")
    if [[ -f "$TASKS_DIR/$i.end" ]]; then
        end=$(<"$TASKS_DIR/$i.end")
    else
        end=$(_task_now)
    fi
    printf '%s' $((end - start))
}

# The spinner's frames, and the colours it runs through: the theme's blue to
# its purple and back (common.sh's palette).
_T_SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
# Clears the line a frame is drawn over again; nothing without a terminal.
_T_CL=""
[[ -t 1 ]] && _T_CL=$'\e[2K'
_T_SWEEP=()
_tasks_sweep() {
    ((${#_T_SWEEP[@]} == 0)) || return 0
    if [[ -z "${UI_ACCENT_BLUE:-}" || -z "${UI_ACCENT_PURPLE:-}" ]]; then
        _T_SWEEP=("$_C_BLUE" "$_C_PURPLE")
        return
    fi
    local from=$UI_ACCENT_BLUE to=$UI_ACCENT_PURPLE k steps=12
    local r1=$((0x${from:0:2})) g1=$((0x${from:2:2})) b1=$((0x${from:4:2}))
    local r2=$((0x${to:0:2})) g2=$((0x${to:2:2})) b2=$((0x${to:4:2}))
    for ((k = 0; k <= steps; k++)); do
        _T_SWEEP+=("$(printf '\e[38;2;%d;%d;%dm' $((r1 + (r2 - r1) * k / steps)) $((g1 + (g2 - g1) * k / steps)) $((b1 + (b2 - b1) * k / steps)))")
    done
    for ((k = steps - 1; k > 0; k--)); do
        _T_SWEEP+=("${_T_SWEEP[k]}")
    done
}

# The spinner of frame `frame`, `offset` along the sweep (a step's own).
_task_spinner() {
    local n=${#_T_SWEEP[@]}
    printf '%s%s%s' "${_T_SWEEP[($1 + $2) % n]}" "${_T_SPIN[($1 + $2) % ${#_T_SPIN[@]}]}" "$_C_NC"
}

# What step i came to: the last line it printed, its mark taken off.
_task_settle() {
    local i=$1 line
    line=$(sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\r//g' "$TASKS_DIR/$i.out" | awk 'NF { l = $0 } END { print l }')
    line=${line#"${line%%[![:space:]]*}"}
    _TASK_KIND[i]=ok
    case $line in
    "✓"*) line=${line#✓} ;;
    "⚠"*)
        line=${line#⚠}
        _TASK_KIND[i]=warn
        ;;
    esac
    line=${line#"${line%%[![:space:]]*}"}
    local rc
    rc=$(<"$TASKS_DIR/$i.rc")
    if [[ "$rc" != 0 ]]; then
        _TASK_KIND[i]=fail
        line="Failed (exit $rc)${line:+: $line}"
    fi
    _TASK_TEXT[i]=$line
}

# Step i's line: mark, label, time, summary; cut at the edge while redrawn, wrapped
# when final.
_task_row() {
    local i=$1 frame=$2 width=$3 cols=$4 final=$5 mark text="" time
    local label=${_TASK_LABELS[i]}
    ((${#label} > width)) && label="${label:0:width-1}…"
    time=$(_task_time "$(_task_elapsed "$i")")
    if [[ -z "${_TASK_KIND[i]:-}" ]]; then
        mark=$(_task_spinner "$frame" $((i * 3)))
    else
        text=${_TASK_TEXT[i]}
        case ${_TASK_KIND[i]} in
        ok) mark="$_C_GREEN✓$_C_NC" ;;
        warn) mark="$_C_YELLOW⚠$_C_NC" ;;
        fail) mark="$_C_RED✗$_C_NC" ;;
        esac
    fi
    # "  ✓ label  12.3s  text": the text starts after 2 + 2 + width + 2 + 6 + 2.
    local indent=$((width + 14)) room
    room=$((cols - indent))
    ((room < 10)) && room=10
    local color=""
    [[ "${_TASK_KIND[i]:-}" == fail ]] && color=$_C_RED
    if ((${#text} <= room)); then
        printf '%s  %s %-*s  %s%6s%s  %s%s%s\n' "$_T_CL" "$mark" "$width" "$label" "$_C_DIM" "$time" "$_C_NC" "$color" "$text" "$_C_NC"
    elif [[ "$final" == 0 ]]; then
        printf '%s  %s %-*s  %s%6s%s  %s%s…%s\n' "$_T_CL" "$mark" "$width" "$label" "$_C_DIM" "$time" "$_C_NC" "$color" "${text:0:room-1}" "$_C_NC"
    else
        local first=1 part
        while IFS= read -r part; do
            if ((first)); then
                printf '%s  %s %-*s  %s%6s%s  %s%s%s\n' "$_T_CL" "$mark" "$width" "$label" "$_C_DIM" "$time" "$_C_NC" "$color" "$part" "$_C_NC"
                first=0
            else
                printf '%s%*s%s%s%s\n' "$_T_CL" "$indent" "" "$color" "$part" "$_C_NC"
            fi
        done < <(fold -s -w "$room" <<<"$text" | sed 's/ *$//')
    fi
}

# The section's heading: its bullet runs through the sweep while the steps
# do, then it says how many there were and how long they took.
_tasks_heading() {
    local title=$1 frame=$2 finished=$3 total=$4 n=${#_TASK_LABELS[@]} bullet tail
    if ((finished < n)); then
        bullet="${_T_SWEEP[frame % ${#_T_SWEEP[@]}]}●$_C_NC"
        tail="$finished/$n"
    else
        bullet="$_C_BLUE●$_C_NC"
        tail="$n steps · $(_task_time "$total")"
    fi
    printf '%s%s %s%s%s  %s%s%s\n' "$_T_CL" "$bullet" "$_C_BOLD" "$title" "$_C_NC" "$_C_DIM" "$tail" "$_C_NC"
}

_tasks_draw() {
    local title=$1 started=$2 width=$3 n=${#_TASK_LABELS[@]} frame=0 finished i cols
    cols=$(tput cols 2>/dev/null || echo 80)
    printf '\e[?25l'
    trap 'printf "\e[?25h"; kill "${_TASK_PIDS[@]}" 2>/dev/null; exit 130' INT TERM
    while :; do
        finished=0
        for ((i = 0; i < n; i++)); do
            if [[ -z "${_TASK_KIND[i]:-}" && -f "$TASKS_DIR/$i.rc" ]]; then
                _task_settle "$i"
            fi
            [[ -n "${_TASK_KIND[i]:-}" ]] && finished=$((finished + 1))
        done
        ((frame == 0)) || printf '\e[%dA' $((n + 1))
        _tasks_heading "$title" "$frame" "$finished" $(($(_task_now) - started))
        for ((i = 0; i < n; i++)); do
            _task_row "$i" "$frame" "$width" "$cols" $((finished == n))
        done
        ((finished == n)) && break
        frame=$((frame + 1))
        sleep 0.08
    done
    printf '\e[?25h'
    trap - INT TERM
}

# Without a terminal (a timer's run, into the journal): the lines once done.
_tasks_print() {
    local title=$1 started=$2 width=$3 n=${#_TASK_LABELS[@]} i
    wait "${_TASK_PIDS[@]}" 2>/dev/null || true
    for ((i = 0; i < n; i++)); do
        _task_settle "$i"
    done
    _tasks_heading "$title" 0 "$n" $(($(_task_now) - started))
    for ((i = 0; i < n; i++)); do
        _task_row "$i" 0 "$width" 200 1
    done
}

# What a failed step printed, under the section; all of it in the log.
_tasks_report() {
    local n=${#_TASK_LABELS[@]} i out
    for ((i = 0; i < n; i++)); do
        out=$(<"$TASKS_DIR/$i.out")
        if [[ -n "$TASKS_LOG" ]]; then
            printf '== %s (exit %s)\n%s\n\n' "${_TASK_LABELS[i]}" "$(<"$TASKS_DIR/$i.rc")" "$out" >>"$TASKS_LOG"
        fi
        [[ "${_TASK_KIND[i]}" == fail ]] || continue
        TASKS_FAILED=$((TASKS_FAILED + 1))
        printf '\n  %s%s:%s\n' "$_C_RED" "${_TASK_LABELS[i]}" "$_C_NC"
        if [[ -n "$out" ]]; then
            tail -n 15 <<<"$out" | sed "s/^/    /"
        fi
    done
    if ((TASKS_FAILED > 0)) && [[ -n "$TASKS_LOG" ]]; then
        printf '    %sAll of it: %s%s\n' "$_C_DIM" "${TASKS_LOG/#$HOME/\~}" "$_C_NC"
    fi
}

run_tasks() {
    local title=$1 n=${#_TASK_LABELS[@]} i started width=0
    ((n > 0)) || return 0
    started=$(_task_now)
    for ((i = 0; i < n; i++)); do
        [[ -n "${_TASK_PIDS[i]:-}" ]] || _task_spawn "$i"
        ((${#_TASK_LABELS[i]} > width)) && width=${#_TASK_LABELS[i]}
    done
    _tasks_sweep
    printf '\n'
    if [[ -t 1 ]]; then
        _tasks_draw "$title" "$started" "$width"
    else
        _tasks_print "$title" "$started" "$width"
    fi
    wait "${_TASK_PIDS[@]}" 2>/dev/null || true
    _tasks_report
    _TASK_LABELS=() _TASK_FUNCS=() _TASK_PIDS=() _TASK_TEXT=() _TASK_KIND=()
    rm -f -- "$TASKS_DIR"/*.{start,end,rc,out}
}
