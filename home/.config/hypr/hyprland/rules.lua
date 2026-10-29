-- Window rules. The special workspaces' own are in specials.lua.

local ui = require("ui")

hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	name = "picture-in-picture",
	match = { title = "^(Picture-in-Picture)$" },
	float = true,
	pin = true,
	idle_inhibit = "always",
})

hl.window_rule({
	name = "webcam-overlay",
	match = { title = "^(WebcamOverlay)$" },
	float = true,
	pin = true,
	no_initial_focus = true,
	no_dim = true,
})

hl.window_rule({
	-- Steam places its toasts by X11 coordinates, which xwayland-satellite
	-- drops, so without this they float in the middle of the screen.
	name = "steam-toasts",
	match = { class = "^(steam)$", title = "^(notificationtoasts_.*)$" },
	float = true,
	pin = true,
	move = string.format(
		"monitor_w-window_w-%d monitor_h-window_h-%d",
		ui.spacing.gaps_out,
		ui.spacing.gaps_out
	),
	no_initial_focus = true,
	no_dim = true,
})

hl.window_rule({
	-- The screenshot editor: over the desktop, big enough to see the detail
	-- being drawn on.
	name = "screenshot-editor",
	match = { class = "^(com.gabm.satty)$" },
	float = true,
	size = "monitor_w*0.8 monitor_h*0.8",
	center = true,
})

hl.window_rule({
	name = "idle-inhibit-fullscreen",
	match = { class = ".*" },
	idle_inhibit = "fullscreen",
})

hl.window_rule({
	match = {
		class = "^(org.gnome.*|com.saivert.pwvucontrol|xdg-desktop-portal-gtk)$",
	},
	float = true,
	center = true,
})
