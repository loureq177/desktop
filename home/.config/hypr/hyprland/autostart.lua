local env = require("hyprland.env")
local machine = require("hyprland.machine")

hl.on("hyprland.start", function()
	-- Xwayland is off in Hyprland: xwayland-satellite.socket owns :0 and starts
	-- it for the first X11 client. Hyprland drops DISPLAY when it loads the
	-- config with Xwayland disabled, so it has to be set here, before anything
	-- is spawned or exported.
	env.set("DISPLAY", ":0")

	local cmds = {
		-- First: autologin opened the session, the lock closes it before anything
		-- else is on screen.
		"hyprlock --config ~/.config/hypr/hyprlock-boot.conf",

		-- The session target starts the shell (quickshell.service). Nothing stops
		-- the target when Hyprland exits, so after a restart a plain start would
		-- be a no-op and leave its services bound to the dead compositor.
		"sh -c 'dbus-update-activation-environment --systemd "
			.. table.concat(env.exported, " ")
			.. "; systemctl --user reset-failed; systemctl --user restart hyprland-session.target'",

		-- The GTK settings of ui.toml, which apply-ui keeps.
		"~/.local/bin/apply-ui --gtk",
		"~/.local/bin/wallpaper init",
		-- install.sh cannot do this before Firefox has made a profile.
		"sh -c '~/.local/bin/firefox-apply >/dev/null 2>&1'",
	}
	for _, cmd in ipairs(machine.autostart) do
		table.insert(cmds, cmd)
	end
	for _, cmd in ipairs(cmds) do
		hl.exec_cmd(cmd)
	end
end)
