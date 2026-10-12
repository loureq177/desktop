#!/usr/bin/env bats
# firefox-apply, firefox-webapp, rclone-sync, mesa-egl, dgpu-run

load helpers

setup() {
    sandbox_setup
    FF="$HOME/.config/mozilla/firefox"
    WEBAPPS="$HOME/.local/share/firefox-webapps"
    cp -r "$REPO/archlinux/.config/firefox-defaults" "$HOME/.config/firefox-defaults"
    stub firefox "echo \"firefox-env MOZ_APP_REMOTINGNAME=\$MOZ_APP_REMOTINGNAME\" >>'$CALLS'"
    stub notify-send
}

# --- firefox-apply -----------------------------------------------------------

# profiles_ini: reads the ini from stdin and creates the given profile dirs.
profiles_ini() {
    mkdir -p "$FF"
    cat >"$FF/profiles.ini"
    local dir
    for dir in "$@"; do mkdir -p "$dir"; done
}

assert_user_js_in() {
    assert_status 0
    cmp "$1/user.js" "$REPO/archlinux/.config/firefox-defaults/user.js"
    [[ "$(stat -c %a "$1/user.js")" == 600 ]]
}

@test "firefox-apply: fails clearly when Firefox has never been started" {
    sut "$BIN/firefox-apply"
    assert_status 1
    assert_output_like "profiles.ini not found"
}

@test "firefox-apply: installs user.js into the profile the installation uses" {
    profiles_ini "$FF/old.default" "$FF/abc.default-release" <<'EOF'
[Install4F96D1932A9F858E]
Default=abc.default-release
Locked=1

[Profile1]
Name=default
IsRelative=1
Path=old.default
Default=1

[Profile0]
Name=default-release
IsRelative=1
Path=abc.default-release

[General]
StartWithLastProfile=1
Version=2
EOF
    sut "$BIN/firefox-apply"
    assert_user_js_in "$FF/abc.default-release"
    [[ ! -e "$FF/old.default/user.js" ]]
}

@test "firefox-apply: without an install section uses the profile flagged Default=1" {
    profiles_ini "$FF/first" "$FF/second" <<'EOF'
[General]
StartWithLastProfile=1

[Profile0]
Name=first
IsRelative=1
Path=first

[Profile1]
Name=second
IsRelative=1
Path=second
Default=1
EOF
    sut "$BIN/firefox-apply"
    assert_user_js_in "$FF/second"
    [[ ! -e "$FF/first/user.js" ]]
}

@test "firefox-apply: with no default at all uses the first profile" {
    profiles_ini "$FF/first" "$FF/second" <<'EOF'
[Profile0]
Name=first
IsRelative=1
Path=first

[Profile1]
Name=second
IsRelative=1
Path=second
EOF
    sut "$BIN/firefox-apply"
    assert_user_js_in "$FF/first"
}

@test "firefox-apply: honours an absolute profile path" {
    profiles_ini "$SANDBOX/elsewhere/profile" <<EOF
[Profile0]
Name=custom
IsRelative=0
Path=$SANDBOX/elsewhere/profile
Default=1
EOF
    sut "$BIN/firefox-apply"
    assert_user_js_in "$SANDBOX/elsewhere/profile"
}

@test "firefox-apply: fails when the profile dir or any profile is missing" {
    profiles_ini <<'EOF'
[Profile0]
Name=gone
IsRelative=1
Path=gone.default
EOF
    sut "$BIN/firefox-apply"
    assert_status 1
    assert_output_like "profile dir not found"

    profiles_ini <<'EOF'
[General]
Version=2
EOF
    sut "$BIN/firefox-apply"
    assert_status 1
    assert_output_like "no profile found"
}

# --- firefox-webapp ----------------------------------------------------------

zoom_rows() {
    sqlite3 "$WEBAPPS/content-prefs.sqlite" \
        "SELECT COALESCE(g.name, '*'), p.value FROM prefs p LEFT JOIN groups g ON g.id = p.groupID
         JOIN settings s ON s.id = p.settingID WHERE s.name = 'browser.content.full-zoom' ORDER BY 1"
}

@test "firefox-webapp: needs a name and a url" {
    sut "$BIN/firefox-webapp"
    assert_status 1
    assert_output_like "Usage: firefox-webapp"
    sut "$BIN/firefox-webapp" gemini
    assert_status 1
    refute_call_like "firefox"
}

@test "firefox-webapp: opens the url in the chromeless webapps profile" {
    sut "$BIN/firefox-webapp" gemini https://gemini.google.com
    assert_status 0
    assert_call "firefox --profile $WEBAPPS --class=webapps --name=gemini --new-window https://gemini.google.com"
    assert_call "firefox-env MOZ_APP_REMOTINGNAME=webapps"
    grep -q '#TabsToolbar' "$WEBAPPS/chrome/userChrome.css"
    grep -qF 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' "$WEBAPPS/user.js"
}

@test "firefox-webapp: passes extra arguments on to firefox" {
    sut "$BIN/firefox-webapp" mail https://mail.google.com --private-window "two words"
    assert_status 0
    assert_call "firefox --profile $WEBAPPS --class=webapps --name=mail --new-window https://mail.google.com --private-window two words"
}

@test "firefox-webapp: sets 110% zoom globally and per site, once" {
    need sqlite3
    sut "$BIN/firefox-webapp" gemini https://gemini.google.com
    sut "$BIN/firefox-webapp" gemini https://gemini.google.com/app?x=1
    sut "$BIN/firefox-webapp" dev http://localhost:8080/path
    assert_status 0
    [[ "$(zoom_rows)" == $'*|1.1\ngemini.google.com|1.1\nlocalhost|1.1' ]] || fail "$(zoom_rows)"
}

@test "firefox-webapp: launches even without sqlite3" {
    rm -f "$SAFE/sqlite3"
    sut "$BIN/firefox-webapp" gemini https://gemini.google.com
    assert_status 0
    assert_call_like "firefox --profile"
}

# --- rclone-sync -------------------------------------------------------------

@test "rclone-sync: syncs the home dir to the default remote, skipping dotfiles and build dirs" {
    stub rclone
    sut "$BIN/rclone-sync"
    assert_status 0
    assert_call_like "rclone sync $HOME google-drive-backup:mlorenc-backup --exclude=.*/** --exclude=.* --exclude=node_modules/**"
    assert_call_like "--drive-use-trash=true"
    refute_call_like "--progress"
    refute_call_like "notify-send"
}

@test "rclone-sync: backup.conf overrides source and remote" {
    stub rclone
    mkdir -p "$HOME/.config/rclone"
    printf 'RCLONE_BACKUP_SOURCE="%s/My Docs"\nRCLONE_BACKUP_REMOTE="b2:bucket"\n' "$HOME" >"$HOME/.config/rclone/backup.conf"
    sut "$BIN/rclone-sync"
    assert_status 0
    assert_call_like "rclone sync $HOME/My Docs b2:bucket --exclude"
}

@test "rclone-sync: the example config is a valid starting point" {
    stub rclone
    mkdir -p "$HOME/.config/rclone"
    cp "$REPO/archlinux/.config/rclone/backup.conf.example" "$HOME/.config/rclone/backup.conf"
    sut "$BIN/rclone-sync"
    assert_status 0
    assert_call_like "rclone sync "
}

@test "rclone-sync: a failed sync notifies and keeps rclone's exit code" {
    stub rclone 'exit 7'
    sut "$BIN/rclone-sync"
    assert_status 7
    assert_call_like "Rclone Sync failed"
}

@test "rclone-sync: does not start twice" {
    stub rclone
    exec 9>"$XDG_RUNTIME_DIR/rclone-sync.lock"
    flock -n 9
    sut "$BIN/rclone-sync"
    exec 9>&-
    assert_status 0
    assert_output_like "already running"
    refute_call_like "rclone"
}

# --- mesa-egl / dgpu-run -----------------------------------------------------

@test "mesa-egl: runs the command with its arguments and exit status" {
    sut env -u AQ_DRM_DEVICES -u __EGL_VENDOR_LIBRARY_FILENAMES "$BIN/mesa-egl" sh -c 'echo "$1|$2|${__EGL_VENDOR_LIBRARY_FILENAMES-unset}"; exit 7' _ "a b" c
    assert_status 7
    [[ "$output" == "a b|c|unset" ]] || fail "$output"
}

@test "mesa-egl: keeps an EGL vendor the user chose and ignores unknown cards" {
    sut env AQ_DRM_DEVICES=/dev/dri/card1 __EGL_VENDOR_LIBRARY_FILENAMES=/custom.json "$BIN/mesa-egl" sh -c 'echo "$__EGL_VENDOR_LIBRARY_FILENAMES"'
    assert_status 0
    [[ "$output" == /custom.json ]]

    sut env -u __EGL_VENDOR_LIBRARY_FILENAMES AQ_DRM_DEVICES=/dev/dri/no-such-card "$BIN/mesa-egl" sh -c 'echo "${__EGL_VENDOR_LIBRARY_FILENAMES-unset}"'
    assert_status 0
    [[ "$output" == unset ]] || fail "$output"
}

@test "dgpu-run: drops the iGPU Vulkan pin before handing over to prime-run" {
    stub prime-run "echo \"prime-env \${VK_DRIVER_FILES-unset} \${VK_ICD_FILENAMES-unset}\" >>'$CALLS'"
    sut env VK_DRIVER_FILES=/igpu.json VK_ICD_FILENAMES=/igpu.json "$BIN/dgpu-run" game --flag "two words"
    assert_status 0
    assert_call "prime-run game --flag two words"
    assert_call "prime-env unset unset"
}
