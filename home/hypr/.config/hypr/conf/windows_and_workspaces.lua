--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

local programs = require("conf.programs")

-- Example window rules that are useful
local suppressMaximizeRule = hl.window_rule({
	-- Ignore maximize requests from all apps. You'll probably like this.
	name = "suppress-maximize-events",
	match = { class = ".*" },

	suppress_event = "maximize",
})
suppressMaximizeRule:set_enabled(true)

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

	move = "20 95%",
	float = true,
})

hl.config({
	misc = {
		focus_on_activate = true,
	},
})

hl.workspace_rule({
	workspace = "special:discord",
	on_created_empty = programs.discord,
	gaps_out = { top = 54, right = 96, bottom = 54, left = 96 },
	gaps_in = 0,
})

hl.workspace_rule({
	workspace = "special:spotify",
	on_created_empty = programs.spotify,
	gaps_out = { top = 54, right = 96, bottom = 54, left = 96 },
	gaps_in = 0,
})

-- Zen
hl.window_rule({
	match = { class = ".*[Zz]en.*" },
	workspace = "1",
})

hl.window_rule({
	match = { class = "galculator" },
	workspace = "special:special",
	size = "300 500",
	float = true,
	center = true,
})

hl.workspace_rule({
	workspace = "special:focus",
	gaps_out = { top = 54, right = 96, bottom = 54, left = 96 },
	gaps_in = 0,
})
