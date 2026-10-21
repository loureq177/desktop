#!/usr/bin/env bats
# The pieces of the repo agree with each other: callers and handlers, units and
# scripts, stow packages and ignore rules, package lists and the tools used.

load helpers

QS="archlinux/.config/quickshell"
UNITS="archlinux/.config/systemd/user"

# --- quickshell --------------------------------------------------------------

@test "every 'qs ipc call' matches an IpcHandler target, function and arity" {
    local files
    mapfile -t files < <(repo_files | grep -v '^tests/')
    run python3 "$BATS_TEST_DIRNAME/tools/ipc_check.py" "$REPO" "${files[@]}"
    assert_status 0
}

@test "members used on quickshell singletons and JS modules exist" {
    run python3 "$BATS_TEST_DIRNAME/tools/qml_refs.py" "$REPO/$QS"
    assert_status 0
}

@test "qml files referenced by name exist" {
    # Loader/Component sources and shader paths given as strings.
    local bad=0 ref file dir
    while IFS=: read -r file ref; do
        dir="$(dirname "$REPO/$file")"
        [[ -e "$dir/$ref" || -e "$REPO/$QS/$ref" ]] || { echo "$file: missing $ref" >&2; bad=1; }
    done < <(cd "$REPO" && grep -oE '"[A-Za-z0-9_.][A-Za-z0-9_./-]*\.(qml|qsb|frag|json|js)"' -r "$QS" --include='*.qml' | tr -d '"' | sort -u)
    [[ "$bad" -eq 0 ]]
}

@test "the shell's own icons that Specials.js names are in the repo" {
    local bad=0 icon
    while IFS= read -r icon; do
        [[ -f "$REPO/$QS/$icon" ]] || { echo "Specials.js: missing $icon" >&2; bad=1; }
    done < <(grep -oE '"icons/[^"]+"' "$REPO/$QS/Specials.js" | tr -d '"')
    [[ "$bad" -eq 0 ]]
}

# --- script references -------------------------------------------------------

@test "every referenced ~/.local/bin script exists and is executable" {
    local bad=0 file name
    while IFS=: read -r file name; do
        if [[ ! -x "$REPO/archlinux/.local/bin/$name" && ! -x "$REPO/macos/.local/bin/$name" ]]; then
            echo "$file refers to .local/bin/$name, which does not exist" >&2
            bad=1
        fi
    done < <(
        cd "$REPO" && repo_files | grep -v '^tests/' | tr '\n' '\0' |
            xargs -0 grep -IoE '\.local/bin/[A-Za-z0-9_-]+' 2>/dev/null |
            sed -E 's|:\.local/bin/|:|' | sort -u
    )
    [[ "$bad" -eq 0 ]]
}

@test "hyprland webapps and helper paths point at existing scripts" {
    # hyprland.lua builds these as  bin .. "/name args"
    local bad=0 name
    while IFS= read -r name; do
        [[ -x "$REPO/archlinux/.local/bin/$name" ]] || { echo "hyprland.lua: bin .. \"/$name\" does not exist" >&2; bad=1; }
    done < <(grep -oE 'bin \.\. "/[A-Za-z0-9_-]+' "$REPO/archlinux/.config/hypr/hyprland.lua" | sed 's|.*/||' | sort -u)
    [[ "$bad" -eq 0 ]]
}

@test "sourced shell libraries exist" {
    local bad=0 file name
    while IFS=: read -r file name; do
        [[ -f "$REPO/archlinux/.local/lib/$name" || -f "$REPO/common/.local/lib/$name" ]] ||
            { echo "$file sources missing .local/lib/$name" >&2; bad=1; }
    done < <(cd "$REPO" && grep -IoE '\.local/lib/[A-Za-z0-9_./-]+' -r archlinux common install.sh | sed -E 's|:\.local/lib/|:|' | sort -u)
    [[ "$bad" -eq 0 ]]
}

# --- systemd -----------------------------------------------------------------

@test "systemd units start scripts that exist" {
    local bad=0 unit script
    while IFS=: read -r unit script; do
        [[ -x "$REPO/archlinux/.local/bin/$script" ]] || { echo "$unit: ExecStart script '$script' is missing" >&2; bad=1; }
    done < <(cd "$REPO" && grep -oE '^Exec[A-Za-z]*=-?%h/\.local/bin/[A-Za-z0-9_-]+' "$UNITS"/*.service | sed -E 's|:Exec[A-Za-z]*=-?%h/\.local/bin/|:|')
    [[ "$bad" -eq 0 ]]
}

@test "every timer has its service, and can be enabled" {
    local timer
    for timer in "$REPO/$UNITS"/*.timer; do
        [[ -f "${timer%.timer}.service" ]] || fail "no service for ${timer##*/}"
        grep -q '^\[Install\]' "$timer" || fail "${timer##*/} has no [Install] section"
    done
}

@test "units install.sh enables say what pulls them in" {
    local unit
    for unit in "$REPO/$UNITS"/*.{timer,service,socket}; do
        grep -q '^\[Install\]' "$unit" || continue
        grep -q '^WantedBy=' "$unit" || fail "${unit##*/} has [Install] but no WantedBy=, so 'enable' does nothing"
    done
}

@test "session services belong to the Hyprland session, not to the login" {
    local unit
    for unit in "$REPO/$UNITS"/*.service; do
        grep -q '^\[Install\]' "$unit" || continue
        grep -qx 'WantedBy=hyprland-session.target' "$unit" || fail "${unit##*/} is not wanted by hyprland-session.target"
        grep -qx 'PartOf=hyprland-session.target' "$unit" || fail "${unit##*/} does not stop with hyprland-session.target"
    done
}

@test "install.sh enables external units that the package lists install" {
    grep -q 'enable hypridle.service' "$REPO/install.sh"
    grep -qx hypridle "$REPO/archlinux/packages.txt"
    grep -q 'enable wayland-pipewire-idle-inhibit.service' "$REPO/install.sh"
    grep -qx wayland-pipewire-idle-inhibit "$REPO/archlinux/aur.txt"
}

@test "every /etc config has its package in the lists" {
    # config under archlinux/etc -> the package that reads it
    local -A owner=(
        [etc/systemd/zram-generator.conf]=zram-generator
    )
    local file
    for file in "${!owner[@]}"; do
        [[ -f "$REPO/archlinux/$file" ]] || fail "$file is gone: drop it from this test"
        grep -qx "${owner[$file]}" "$REPO/archlinux/packages.txt" || fail "$file needs ${owner[$file]}, which packages.txt does not install"
    done
}

@test "no listed package needs a repository that install.sh does not enable" {
    need pacman
    pacman -Si pacman >/dev/null 2>&1 || skip "no pacman sync database"
    local pkgs
    mapfile -t pkgs < <(listed_packages "$REPO"/archlinux/{packages.txt,packages-laptop.txt})
    local outside
    outside="$(pacman -Si "${pkgs[@]}" 2>/dev/null | awk '/^Repository/ {repo=$3} /^Name/ && repo != "core" && repo != "extra" {print $3 " (" repo ")"}')"
    [[ -z "$outside" ]] || fail "not in core/extra, which is all a fresh pacman.conf enables:" "$outside"
}

@test "units the session target pulls in exist" {
    local unit
    for unit in $(sed -n 's/^Wants=//p' "$REPO/$UNITS/hyprland-session.target"); do
        [[ "$unit" == graphical-session* ]] && continue
        [[ -f "$REPO/$UNITS/$unit" ]] || fail "hyprland-session.target wants $unit, which is not in the repo"
    done
}

@test "systemd accepts the unit files" {
    need systemd-analyze
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/run"
    mkdir -p "$HOME/.config/systemd" "$HOME/.local" "$XDG_RUNTIME_DIR"
    cp -r "$REPO/$UNITS" "$HOME/.config/systemd/user"
    cp -r "$REPO/archlinux/.local/bin" "$HOME/.local/bin"
    cd "$HOME/.config/systemd/user"
    run systemd-analyze --user verify ./*.service ./*.timer ./*.socket ./*.target
    [[ "$output" != *"Failed to initialize manager"* ]] || skip "systemd cannot start a user manager here"
    # A system binary that is simply not installed on this machine is not a unit bug.
    local problems
    problems="$(grep -vE 'Command /usr/bin/\S+ is not executable|^$' <<<"$output" || true)"
    [[ -z "$problems" ]] || fail "$problems"
}

# --- stow --------------------------------------------------------------------

# stow_ignored PACKAGE: paths stow refuses to link, with every directory
# already present in the target so nothing is hidden behind a folded dir link.
stow_ignored() {
    local target="$BATS_TEST_TMPDIR/target-$1" dir
    while IFS= read -r dir; do mkdir -p "$target/$dir"; done < <(cd "$REPO/$1" && find . -type d -not -path '*/node_modules*')
    (cd "$REPO" && stow --verbose=4 --simulate --target "$target" "$1" 2>&1) |
        sed -n 's/^ *Ignoring path \(.*\) due to .*/\1/p' | sort -u
}

@test "tracked symlinks point at files that exist" {
    # repo_files skips them (-f follows the link), so nothing else would notice.
    local f bad=0
    while IFS= read -r f; do
        [[ -e "$REPO/$f" ]] || { echo "$f -> $(readlink "$REPO/$f") is broken" >&2; bad=1; }
    done < <(git -C "$REPO" ls-files -s | awk '$1 == 120000 { print $4 }')
    [[ "$bad" -eq 0 ]]
}

@test "stow links every tracked file except the ones meant to stay in the repo" {
    need stow
    # Package lists, docs and machine-local files are deliberately not linked.
    local allowed='^(packages(-[a-z]+)?\.txt|aur\.txt|flatpak\.txt|Brewfile|(.*/)?README\.md|\.config/hypr/local\.lua|etc)$'
    local pkg path bad=0
    for pkg in common archlinux macos; do
        while IFS= read -r path; do
            [[ -n "$path" ]] || continue
            git -C "$REPO" ls-files --error-unmatch "$pkg/$path" >/dev/null 2>&1 || continue
            [[ "$path" =~ $allowed ]] && continue
            echo "$pkg/$path is tracked but .stowrc keeps stow from linking it" >&2
            bad=1
        done < <(stow_ignored "$pkg")
    done
    [[ "$bad" -eq 0 ]]
}

@test "stow never links secrets or machine-local files" {
    need stow
    local pkgs="$BATS_TEST_TMPDIR/pkgs" target="$BATS_TEST_TMPDIR/home"
    mkdir -p "$pkgs/fix/.ssh" "$pkgs/fix/.config/hypr" "$target/.ssh" "$target/.config/hypr"
    cp "$REPO/.stowrc" "$pkgs/.stowrc"
    local secret=(.env .env.local .env-production .ssh/id_ed25519 .ssh/id_rsa .ssh/id_ed25519.pub .ssh/known_hosts
        .ssh/known_hosts.old service.json backup.conf config.local .zshrc.local .zsh_history .config/hypr/local.lua)
    local wanted=(.zshenv .ssh/config.example .config/hypr/local.lua.example .config/hypr/hyprland.lua)
    local f
    for f in "${secret[@]}" "${wanted[@]}"; do : >"$pkgs/fix/$f"; done
    (cd "$pkgs" && stow --target "$target" fix)

    local bad=0
    for f in "${secret[@]}"; do
        [[ ! -e "$target/$f" ]] || { echo "linked although it must stay private: $f" >&2; bad=1; }
    done
    for f in "${wanted[@]}"; do
        [[ -e "$target/$f" ]] || { echo "not linked although it is an ordinary dotfile: $f" >&2; bad=1; }
    done
    [[ "$bad" -eq 0 ]]
}

@test "stow packages installed together do not provide the same file" {
    local other clash
    for other in archlinux macos; do
        clash="$(comm -12 <(cd "$REPO/common" && find . -type f | sort) <(cd "$REPO/$other" && find . -type f | sort))"
        [[ -z "$clash" ]] || fail "in both common and $other:" "$clash"
    done
}

@test "stowing common with archlinux or macos has no conflicts" {
    need stow
    local os target
    for os in archlinux macos; do
        target="$BATS_TEST_TMPDIR/home-$os"
        mkdir -p "$target"
        (cd "$REPO" && stow --target "$target" common "$os")
        [[ -z "$(find "$target" -xtype l)" ]] || fail "dangling links:" "$(find "$target" -xtype l)"
    done
}

# --- package lists -----------------------------------------------------------

listed_packages() {
    sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$@" | grep -vE '^(#|$)'
}

@test "package lists have no duplicates or malformed names" {
    local lists=("$REPO"/archlinux/{packages.txt,packages-laptop.txt,aur.txt})
    local dups
    dups="$(listed_packages "${lists[@]}" | sort | uniq -d)"
    [[ -z "$dups" ]] || fail "listed more than once:" "$dups"
    local odd
    odd="$(listed_packages "${lists[@]}" | grep -vE '^[a-z0-9@._+-]+$' || true)"
    [[ -z "$odd" ]] || fail "not a package name:" "$odd"
    odd="$(listed_packages "$REPO/archlinux/flatpak.txt" | grep -vE '^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+){2,}$' || true)"
    [[ -z "$odd" ]] || fail "not a flatpak app id:" "$odd"
}

@test "official packages exist in the pacman repositories" {
    need pacman
    pacman -Si pacman >/dev/null 2>&1 || skip "no pacman sync database"
    local pkgs
    mapfile -t pkgs < <(listed_packages "$REPO"/archlinux/{packages.txt,packages-laptop.txt})
    run pacman -Si "${pkgs[@]}"
    local missing
    missing="$(grep -E "^error: package '.*' was not found" <<<"$output" || true)"
    [[ -z "$missing" ]] || fail "$missing"
}

@test "AUR packages are not in the official repositories" {
    need pacman
    pacman -Si pacman >/dev/null 2>&1 || skip "no pacman sync database"
    local pkg bad=0
    while IFS= read -r pkg; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            echo "$pkg is in the official repos now: move it from aur.txt to packages.txt" >&2
            bad=1
        fi
    done < <(listed_packages "$REPO/archlinux/aur.txt")
    [[ "$bad" -eq 0 ]]
}

@test "the package lists install every program the scripts and units need" {
    need pacman pactree
    pacman -Si pacman >/dev/null 2>&1 || skip "no pacman sync database"
    # Programs the dotfiles call. Keep in step with the scripts; optional
    # tools guarded by `command -v` (showtime, fwupdmgr, ...) are left out.
    local needed=(
        qs notify-send nmcli brightnessctl checkupdates pacdiff paccache cliphist wl-copy wl-paste wtype
        hyprctl Hyprland hypridle hyprsunset hyprpicker pw-record sox whisper-cli flock jq sqlite3 firefox grim slurp
        tesseract canberra-gtk-play satty wf-recorder pactl wpctl v4l2-ctl ffplay powerprofilesctl
        curl playerctl stow bat nvim zsh python3 gsettings systemd-inhibit xdg-open ghostty flatpak
        yazi btop lazygit fzf git
    )
    # Not installable from a list: install.sh builds paru from the AUR,
    # prime-run only matters on NVIDIA machines.
    local unit_bins
    mapfile -t unit_bins < <(grep -ohE '^Exec[A-Za-z]*=-?/usr/bin/[A-Za-z0-9_.-]+' "$REPO/$UNITS"/*.service | sed 's|.*/||' | sort -u)

    local provided
    provided="$(
        { listed_packages "$REPO"/archlinux/{packages.txt,packages-laptop.txt,aur.txt}; echo base; } |
            while IFS= read -r pkg; do pactree -lu "$pkg" 2>/dev/null || pactree -slu "$pkg" 2>/dev/null || echo "$pkg"; done | sort -u
    )"

    local cmd path owner bad=0
    for cmd in "${needed[@]}" "${unit_bins[@]}"; do
        path="$(command -v "$cmd" 2>/dev/null)" || { echo "skipping $cmd: not installed here" >&3; continue; }
        owner="$(pacman -Qqo "$path" 2>/dev/null)" || continue
        if ! grep -qxF "$owner" <<<"$provided"; then
            echo "'$cmd' comes from '$owner', which no package list installs" >&2
            bad=1
        fi
    done
    [[ "$bad" -eq 0 ]]
}

# --- misc --------------------------------------------------------------------

@test "the ghostty shader power-save turns on is in the repo" {
    local shader
    shader="$(grep -oE '^GHOSTTY_SHADER=.*/ghostty/shaders/[a-z_]+\.glsl' "$REPO/archlinux/.local/bin/power-save")"
    [[ -n "$shader" ]] || fail "power-save no longer names its shader"
    [[ -f "$REPO/archlinux/.config/ghostty/shaders/${shader##*/}" ]] || fail "missing ${shader##*/}"
}

@test "the default wallpaper that 'wallpaper init' falls back to is in the repo" {
    [[ -s "$REPO/archlinux/.config/hypr/wallpapers/hyprland.webp" ]]
}

@test "example files keep their real counterparts out of git" {
    local example real
    while IFS= read -r example; do
        real="${example%.example}"
        git -C "$REPO" check-ignore -q "$real" || fail "$real would be committed (not in .gitignore), but $example suggests it is machine-local"
    done < <(repo_files '*.example')
}
