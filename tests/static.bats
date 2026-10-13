#!/usr/bin/env bats
# Every file parses with the interpreter that will run it.

load helpers

shebang_files() {
    local f first
    repo_files | while IFS= read -r f; do
        IFS= read -r first <"$REPO/$f" || true
        [[ "$first" =~ ^#!.*[/\ ]($1)($|\ ) ]] && printf '%s\n' "$f"
    done
    return 0
}

# check_each CMD... : run CMD FILE for every file on stdin, report all failures.
check_each() {
    local f out bad=0
    while IFS= read -r f; do
        if ! out="$("$@" "$REPO/$f" 2>&1)"; then
            printf '%s\n%s\n' "FAILED: $f" "$out" >&2
            bad=1
        fi
    done
    return "$bad"
}

@test "scripts in .local/bin are executable and have a shebang" {
    local f first bad=0
    while IFS= read -r f; do
        IFS= read -r first <"$REPO/$f" || true
        [[ -x "$REPO/$f" ]] || { echo "not executable: $f" >&2; bad=1; }
        [[ "$first" == '#!'* ]] || { echo "no shebang: $f" >&2; bad=1; }
    done < <(repo_files 'archlinux/.local/bin/*' 'macos/.local/bin/*' install.sh)
    [[ "$bad" -eq 0 ]]
}

@test "bash and sh scripts parse" {
    { shebang_files 'bash'; repo_files '*.sh' '*.bash'; } | sort -u | check_each bash -n
    shebang_files 'sh' | check_each sh -n
}

@test "zsh scripts and zsh config parse" {
    need zsh
    { shebang_files 'zsh'; repo_files 'common/.zshenv' 'common/.config/zsh/.zshrc' 'common/.config/zsh/.zprofile'; } |
        sort -u | check_each zsh -n
}

@test "shellcheck finds no warnings" {
    need shellcheck
    cd "$REPO"
    { shebang_files 'bash|sh'; repo_files '*.sh'; } | sort -u |
        check_each shellcheck -S warning -s bash -x -e SC1090,SC1091
}

@test "python scripts compile and use no undefined names" {
    shebang_files 'python3?' | check_each python3 -c 'import sys; compile(open(sys.argv[1]).read(), sys.argv[1], "exec")'
    command -v ruff >/dev/null || skip "undefined-name part needs ruff"
    shebang_files 'python3?' | check_each ruff check --no-cache --quiet --select E9,F63,F7,F82
}

@test "lua files parse" {
    need luac
    repo_files '*.lua' '*.lua.example' | check_each luac -p
}

@test "json files parse" {
    repo_files '*.json' '*.json.example' |
        check_each python3 -c 'import json, sys; json.load(open(sys.argv[1], encoding="utf-8"))'
}

@test "toml files parse" {
    repo_files '*.toml' | check_each python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))'
}

@test "javascript files parse" {
    need node
    # QML's ".pragma library" line is not JavaScript; blank it out for the syntax check.
    local f bad=0
    while IFS= read -r f; do
        sed 's/^\.pragma .*$//' "$REPO/$f" >"$BATS_TEST_TMPDIR/check.js"
        node --check "$BATS_TEST_TMPDIR/check.js" || { echo "FAILED: $f" >&2; bad=1; }
    done < <(repo_files '*.js')
    [[ "$bad" -eq 0 ]]
}

@test "qml files have no syntax errors" {
    # /usr/bin/qmllint may be the Qt5 one, which cannot read these files.
    local qmllint=/usr/lib/qt6/bin/qmllint
    [[ -x "$qmllint" ]] || qmllint="$(command -v qmllint6 || true)"
    [[ -n "$qmllint" ]] || skip "needs Qt6 qmllint"
    cd "$REPO"
    local files
    mapfile -t files < <(repo_files '*.qml')
    run "$qmllint" "${files[@]}"
    # qmllint exits non-zero for syntax errors only; type warnings are noise
    # here because quickshell's own types are not all visible to it.
    [[ "$status" -eq 0 ]] || fail "$(grep -B1 -A3 -F '[syntax]' <<<"$output")"
}

@test "git config parses" {
    git config --file "$REPO/common/.config/git/config" --list >/dev/null
}

@test "keyd config is valid" {
    need keyd
    run keyd check "$REPO/archlinux/etc/keyd/default.conf"
    assert_status 0
    assert_output_like "No errors found"
}

@test "ghostty config is valid" {
    need ghostty
    # arch.conf is included from the main config through ~/.config.
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME/.config/ghostty"
    cp -r "$REPO/common/.config/ghostty/." "$REPO/archlinux/.config/ghostty/." "$HOME/.config/ghostty/"
    run ghostty +validate-config --config-file="$HOME/.config/ghostty/config"
    assert_status 0
}

@test "compiled quickshell shader matches its source" {
    local qsb=/usr/lib/qt6/bin/qsb
    [[ -x "$qsb" ]] || skip "needs Qt6 qsb"
    local dir="$REPO/archlinux/.config/quickshell/shaders"
    "$qsb" --qt6 -o "$BATS_TEST_TMPDIR/grow.frag.qsb" "$dir/grow.frag"
    cmp "$BATS_TEST_TMPDIR/grow.frag.qsb" "$dir/grow.frag.qsb" ||
        fail "grow.frag.qsb is stale: rebuild it with qsb --qt6 -o grow.frag.qsb grow.frag"
}

@test "emoji table has the shape the launcher reads" {
    python3 - "$REPO/archlinux/.config/quickshell/emojis.json" <<'EOF'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert isinstance(data, list) and len(data) > 100, "expected a long list"
bad = [e for e in data if not (isinstance(e, dict) and e.get("e") and isinstance(e.get("k"), str))]
assert not bad, f"entries without e/k: {bad[:3]}"
seen, dups = set(), set()
for e in data:
    (dups if e["e"] in seen else seen).add(e["e"])
assert not dups, f"duplicate emoji: {sorted(dups)[:10]}"
EOF
}
