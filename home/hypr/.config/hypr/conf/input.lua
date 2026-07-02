hl.config({
	input = {
		kb_layout = "pl",
		kb_variant = "",
		kb_model = "",
		kb_options = "caps:escape,altwin:swap_lalt_lwin",
		kb_rules = "",
		repeat_delay = 200,
		repeat_rate = 20,
		follow_mouse = 1,
		sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.
		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
		},
	},
	gestures = {
		workspace_swipe_touch = true,
		workspace_swipe_cancel_ratio = 0.05,
	},
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({
	fingers = 2,
	direction = "pinchin",
	mods = "SUPER",
	action = "cursorZoom",
	zoom_level = 2.0,
	mode = "mult",
})
hl.gesture({
	fingers = 2,
	direction = "pinchout",
	mods = "SUPER",
	action = "cursorZoom",
	zoom_level = 0.5,
	mode = "mult",
})
