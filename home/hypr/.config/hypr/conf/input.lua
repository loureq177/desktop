hl.config({
	input = {
		kb_layout = "pl",
		kb_variant = "",
		kb_model = "",
		kb_options = "caps:escape,altwin:swap_lalt_lwin",
		kb_rules = "",
		repeat_delay = 200,
		repeat_rate = 25,
		follow_mouse = 1,
		sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.
		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
		},
	},
})

hl.gesture({ fingers = 3, direction = "horizontal", scale = 2.0, action = "workspace" })
hl.gesture({ fingers = 2, direction = "pinchin", action = "cursorZoom", zoom_level = 2.0, mode = "mult" })
hl.gesture({ fingers = 2, direction = "pinchout", action = "cursorZoom", zoom_level = 0.5, mode = "mult" })

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
-- hl.device({
-- 	name = "epic-mouse-v1",
-- 	sensitivity = -0.5,
-- })
