#!/usr/bin/env bats
# sysclean and sysupdate, Arch and macOS flavours

load helpers

setup() {
    sandbox_setup
    MAC="$REPO/macos/.local/bin"
    stub sudo
    stub notify-send
    local tool
    for tool in pacman paccache flatpak gio uv pip bun npm podman docker pkexec tldr nvim brew mas pipx softwareupdate yarn qlmanage; do
        stub "$tool"
    done
    # sysupdate updates the zsh plugins through `zsh -ic ...`.
    stub zsh
    stub systemctl
    stub paru
    stub pacdiff
}

# --- sysclean (Arch) ---------------------------------------------------------

sysclean() {
    # The script also empties /tmp/paru, which is outside the sandbox.
    if compgen -G "/tmp/paru/*" >/dev/null; then skip "/tmp/paru is in use on this machine"; fi
    sut "$BIN/sysclean" "$@"
}

orphans() {
    stub paru "[[ \"\$1\" == -Qdtq ]] && printf '%s\n' $*; true"
}

# sysclean --root, as pkexec or sudo would run it. rm is a stub here: the root
# steps only delete under /usr/lib/modules and /var/lib/systemd/coredump.
sysclean_root() {
    stub_quiet id 'echo 0'
    stub rm
    stub journalctl
    sut "$BIN/sysclean" --root
}

@test "sysclean --auto: never asks for root and never deletes user data" {
    orphans orphan-a orphan-b
    sysclean --auto
    assert_status 0
    refute_call_like "sudo"
    refute_call_like "pkexec"
    refute_call_like "gio"
    refute_call_like "podman"
    refute_call_like "docker"
    assert_output_like "Orphans found"
    assert_output_like "orphan-a"
    assert_output_like "Total reclaimed space:"
}

@test "sysclean --auto: prunes user-level caches" {
    mkdir -p "$HOME/.cache/paru/clone/pkg-a" "$HOME/.cache/paru/diff" "$HOME/.cache/paru/pkg" "$HOME/.cache/thumbnails/large" "$HOME/Documents"
    : >"$HOME/.cache/paru/diff/x.diff"
    : >"$HOME/.cache/thumbnails/large/t.png"
    : >"$HOME/Documents/keep.txt"
    sysclean --auto
    assert_status 0
    [[ -z "$(ls -A "$HOME/.cache/paru/clone")" && -z "$(ls -A "$HOME/.cache/paru/diff")" && -z "$(ls -A "$HOME/.cache/thumbnails")" ]]
    [[ -f "$HOME/Documents/keep.txt" ]]
    assert_call "paccache -r -k 2 -c $HOME/.cache/paru/pkg"
    assert_call "flatpak uninstall --user --unused -y"
    assert_call "uv cache prune"
    assert_call "pip cache purge"
    assert_call "bun pm cache rm"
    assert_call "npm cache clean --force"
}

@test "sysclean: asks for root once, in the polkit dialog inside the session" {
    WAYLAND_DISPLAY=wayland-1 sysclean
    assert_status 0
    assert_call "pkexec $BIN/sysclean --root"
    [[ "$(call_count pkexec)" -eq 1 ]] || fail "$(calls)"
    refute_call_like "sudo"
    assert_call "flatpak uninstall --unused -y"
    assert_call "gio trash --empty"
    assert_call "podman system prune -a --force"
    assert_call "docker system prune -a -f"
    refute_call_like "--volumes"
    assert_output_like "Total reclaimed space:"
}

@test "sysclean: outside the session asks for root once through sudo" {
    unset WAYLAND_DISPLAY
    sysclean
    assert_status 0
    assert_call "sudo $BIN/sysclean --root"
    [[ "$(call_count sudo)" -eq 1 ]] || fail "$(calls)"
    refute_call_like "pkexec"
}

@test "sysclean: a cancelled root step still cleans the rest" {
    WAYLAND_DISPLAY=wayland-1
    export WAYLAND_DISPLAY
    stub pkexec 'exit 126'
    sysclean
    assert_status 0
    assert_output_like "Root steps did not finish"
    assert_call "gio trash --empty"
}

@test "sysclean --root: refuses to run without root" {
    sut "$BIN/sysclean" --root
    assert_status 2
    refute_call_like "pacman"
}

@test "sysclean --root: removes orphans, package caches and old journals" {
    stub pacman "[[ \"\$1\" == -Qdtq ]] && printf '%s\n' orphan-a orphan-b; true"
    sysclean_root
    assert_status 0
    assert_call "pacman -Rns --noconfirm orphan-a orphan-b"
    assert_call "paccache -r -k 2"
    assert_call "paccache -r -u -k 0"
    assert_call "journalctl --vacuum-size=200M --vacuum-time=2weeks --quiet"
}

@test "sysclean --root: with no orphans removes no packages" {
    sysclean_root
    assert_status 0
    assert_output_like "No orphaned packages."
    refute_call_like "pacman -Rns"
}

@test "sysclean --root: never removes the running kernel's modules" {
    # pacman claims to own nothing, so every other modules dir counts as orphaned.
    stub pacman 'exit 1'
    sysclean_root
    assert_status 0
    # (a container has no modules dir for the host kernel)
    [[ ! -d "/usr/lib/modules/$(uname -r)" ]] || assert_output_like "Keeping $(uname -r) (running kernel)"
    refute_call_like "rm -rf -- /usr/lib/modules/$(uname -r)"
}

@test "sysclean --root: keeps modules that a package still owns" {
    sysclean_root
    assert_status 0
    refute_call_like "rm -rf -- /usr/lib/modules"
}

@test "sysclean: lists failed services" {
    stub systemctl '[[ "$*" == *--user* ]] && echo "broken.service loaded failed failed Broken thing"; true'
    sysclean --auto
    assert_status 0
    assert_output_like "Failed user services"
    assert_output_like "broken.service"

    stub systemctl
    sysclean --auto
    assert_output_like "No failed services."
}

@test "sysclean: copes with tools that are not installed" {
    rm "$STUBS"/{flatpak,gio,uv,pip,bun,npm,podman,docker,paccache}
    sysclean
    assert_status 0
    assert_output_like "System is clean."
}

# --- sysupdate (Arch) --------------------------------------------------------

@test "sysupdate: upgrades system and AUR, then the user-level tools" {
    WAYLAND_DISPLAY=wayland-1 sut "$BIN/sysupdate"
    assert_status 0
    assert_call "paru -Syu --repo --noconfirm --sudo pkexec"
    assert_call "zsh -ic zinit self-update && zinit update --all"
    assert_call "flatpak update -y"
    assert_call "tldr --update"
    assert_call "uv tool upgrade --all"
    assert_call "nvim --headless +Lazy! sync +qa"
    if [[ -d "/usr/lib/modules/$(uname -r)" ]]; then
        assert_call_like "Update Complete"
    else
        assert_call_like "Reboot Recommended"
    fi
}

@test "sysupdate: never builds AUR packages without a terminal to review them in" {
    stub paru '[[ "$1" == -Qua ]] && echo "some-aur-pkg 1 -> 2"; true'
    sut "$BIN/sysupdate"
    assert_status 0
    assert_output_like "AUR updates are reviewed before they are built"
    refute_call_like "paru -Sua"
    refute_call_like "--skipreview"
}

@test "sysupdate: with no AUR updates pending asks for nothing" {
    sut "$BIN/sysupdate"
    assert_status 0
    assert_output_like "Nothing to update."
    refute_call_like "paru -Sua"
}

@test "sysupdate: stops with the package manager's exit code when the upgrade fails" {
    stub paru 'exit 5'
    sut "$BIN/sysupdate"
    assert_status 5
    assert_output_like "operation aborted"
    refute_call_like "flatpak"
    refute_call_like "nvim"
    refute_call_like "notify-send"
}

@test "sysupdate: falls back to pacman when paru is not installed" {
    rm "$STUBS/paru"
    WAYLAND_DISPLAY=wayland-1 sut "$BIN/sysupdate"
    assert_status 0
    assert_call "pkexec pacman -Syu --noconfirm"
}

@test "sysupdate: outside the graphical session asks through sudo, not pkexec" {
    unset WAYLAND_DISPLAY
    sut "$BIN/sysupdate"
    assert_status 0
    assert_call "paru -Syu --repo --noconfirm --sudo sudo"
    rm "$STUBS/paru"
    : >"$CALLS"
    sut "$BIN/sysupdate"
    assert_call "sudo pacman -Syu --noconfirm"
    refute_call_like "pkexec"
}

@test "sysupdate: points out pending .pacnew files" {
    stub pacdiff '[[ "$1" == -o ]] && echo /etc/pacman.conf.pacnew; true'
    sut "$BIN/sysupdate"
    assert_status 0
    assert_output_like "/etc/pacman.conf.pacnew"
    assert_call_like "Pacnew Files Detected"
}

@test "sysupdate: skips optional tools that are not installed" {
    rm "$STUBS"/{flatpak,tldr,uv,nvim,pacdiff,notify-send}
    sut "$BIN/sysupdate"
    assert_status 0
    if [[ -d "/usr/lib/modules/$(uname -r)" ]]; then
        assert_output_like "System update complete"
    else
        assert_output_like "A system restart is recommended"
    fi
}

# --- macOS -------------------------------------------------------------------

@test "macos sysupdate --help: prints usage and updates nothing" {
    sut "$MAC/sysupdate" --help
    assert_status 0
    assert_output_like "Usage: sysupdate [--only="
    [[ ! -s "$CALLS" ]]
}

@test "macos sysupdate: updates every tool by default" {
    stub mas '[[ "$1" == outdated ]] && echo "123 Xcode (15 -> 16)"; true'
    sut "$MAC/sysupdate"
    assert_status 0
    assert_call "brew update"
    assert_call "brew upgrade --quiet"
    assert_call "mas upgrade"
    assert_call "tldr --update"
    assert_call "uv tool upgrade --all"
    assert_call "pipx upgrade-all"
    assert_call "nvim --headless +Lazy! sync +qa"
    assert_call "softwareupdate -l"
    assert_output_like "macOS update completed"
}

@test "macos sysupdate: does not run mas upgrade when nothing is outdated" {
    sut "$MAC/sysupdate" --only=mas
    assert_status 0
    assert_call "mas outdated"
    refute_call_like "mas upgrade"
}

@test "macos sysupdate --only: runs just the selected steps" {
    sut "$MAC/sysupdate" --only=brew
    assert_status 0
    assert_call "brew update"
    refute_call_like "mas"
    refute_call_like "tldr"
    refute_call_like "nvim"
    refute_call_like "softwareupdate"

    : >"$CALLS"
    sut "$MAC/sysupdate" --only=tldr,nvim
    assert_status 0
    assert_call "tldr --update"
    assert_call "nvim --headless +Lazy! sync +qa"
    refute_call_like "brew"
    refute_call_like "uv"
}

@test "macos sysclean: empties caches and trash inside the home dir" {
    mkdir -p "$HOME/.Trash" "$HOME/Library/Caches/Homebrew" "$HOME/Documents"
    : >"$HOME/.Trash/junk"
    : >"$HOME/Library/Caches/Homebrew/old.tar"
    : >"$HOME/Documents/keep.txt"
    sut "$MAC/sysclean"
    assert_status 0
    assert_call "brew cleanup --prune=all"
    assert_call "brew autoremove"
    assert_call "npm cache clean --force"
    [[ -z "$(ls -A "$HOME/.Trash")" && -z "$(ls -A "$HOME/Library/Caches/Homebrew")" ]]
    [[ -f "$HOME/Documents/keep.txt" ]]
    assert_output_like "Total reclaimed space:"
}
