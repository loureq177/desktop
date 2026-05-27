local mainMod = "SUPER"

hl.config({
	plugin = {
		hyprexpo = {
			columns = 2,
			gaps_in = 5,
			gaps_out = 0,
			bg_col = 0xff111111,
			workspace_method = "first 1",
			gesture_distance = 200,
			cancel_key = "escape",
			show_cursor = 1,

			keynav_enable = 1,
			keynav_wrap_h = 1,
			keynav_wrap_v = 1,
			keynav_reading_order = 0,
		},
	},
})

hl.bind(mainMod .. "+ G", function()
	hl.plugin.hyprexpo.expo("toggle")
end)
