--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
	-- Ignore maximize requests from all apps. You'll probably like this.
	name = "suppress-maximize-events",
	match = { class = ".*" },

	suppress_event = "maximize",
})
suppressMaximizeRule:set_enabled(false)

hl.window_rule({
	-- Fix some dragging issues with XWayland
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},

	no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },

	move = "20 monitor_h-120",
	float = true,
})

-- Discord and Spotify to special workspace as floating
hl.window_rule({
	name = "discord-special",
	match = { class = ".*discord.*" },
	workspace = "special:special",
	float = true,
	size = "90% 90%",
	center = true,
})
hl.window_rule({
	name = "spotify-special",
	match = { class = ".*[Ss]potify.*" },
	workspace = "special:special",
	float = true,
	size = "90% 90%",
	center = true,
})

-- Browser to workspace 1
hl.window_rule({
	name = "browser-workspace",
	match = { class = ".*[Zz]en.*" },
	workspace = "1",
})
