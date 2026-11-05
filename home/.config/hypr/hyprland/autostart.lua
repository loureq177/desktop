local apps = require("hyprland.apps")
local env = require("hyprland.env")
local machine = require("hyprland.machine")

-- Xwayland is off (xwayland-satellite owns :0); Hyprland drops DISPLAY on each
-- config load, so it is set again after every one.
hl.on("config.reloaded", function()
	hl.env("DISPLAY", ":0")
end)

hl.on("hyprland.start", function()
	-- Before anything is spawned or exported.
	env.set("DISPLAY", ":0")

	local cmds = {
		-- First: autologin opened the session, the lock closes it before anything
		-- else is on screen.
		"hyprlock --config ~/.config/hypr/hyprlock-boot.conf",

		-- Restarted, not started: Hyprland starts the target itself, maybe before these
		-- variables reach the session, and its services must have them.
		"sh -c 'dbus-update-activation-environment --systemd "
			.. table.concat(env.exported, " ")
			.. "; systemctl --user reset-failed; systemctl --user restart hyprland-session.target'",

		-- The GTK settings of ui.toml, which apply-ui keeps.
		"~/.local/bin/apply-ui --gtk",
		"~/.local/bin/wallpaper init",
	}
	-- .files' Firefox defaults; install.sh cannot apply them before Firefox has made a profile.
	if apps.browser.exec == "firefox" then
		table.insert(cmds, "sh -c '[ -x ~/.local/bin/firefox-apply ] && ~/.local/bin/firefox-apply'")
	end
	for _, cmd in ipairs(machine.autostart) do
		table.insert(cmds, cmd)
	end
	for _, cmd in ipairs(cmds) do
		hl.exec_cmd(cmd)
	end
end)
