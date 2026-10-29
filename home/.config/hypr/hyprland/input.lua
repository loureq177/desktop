local machine = require("hyprland.machine")

hl.config({
	input = {
		-- The layout belongs to the machine (local.lua).
		kb_layout = machine.keyboard.layout,
		kb_options = machine.keyboard.options,
		repeat_delay = 200,
		repeat_rate = 20,
		sensitivity = 0.2,
		touchpad = {
			natural_scroll = true,
		},
	},
	cursor = {
		warp_on_change_workspace = true,
	},
	-- H and L past the last window go to the next workspace, not the next
	-- monitor (workspaces.lua).
	binds = {
		window_direction_monitor_fallback = false,
	},
	gestures = {
		workspace_swipe_touch = true,
		workspace_swipe_cancel_ratio = 0.02,
	},
})

-- Three fingers up and down are the special workspaces' (specials.lua).
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
