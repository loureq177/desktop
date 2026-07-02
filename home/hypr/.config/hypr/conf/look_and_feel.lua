hl.config({
	general = {
		gaps_in = 10,
		gaps_out = 20,
		border_size = 2,
		col = {
			active_border = {
				colors = { "rgba(33ccffee)", "rgba(00ff99ee)" },
				angle = 45,
			},
			inactive_border = "rgba(292e42ee)",
		},
		resize_on_border = true,
		allow_tearing = false,
		layout = "dwindle",
	},
	decoration = {
		rounding = 16,
		rounding_power = 2,
		active_opacity = 1.0,
		inactive_opacity = 0.70,
		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = 0xee1a1a1a,
		},
		blur = {
			enabled = true,
			size = 3,
			passes = 4,
			vibrancy = 0.1696,
		},
	},
	dwindle = {
		preserve_split = true,
	},
	master = {
		new_status = "master",
	},
	scrolling = {
		fullscreen_on_one_column = true,
	},
})

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "myBezier" })
hl.animation({
	leaf = "windowsIn",
	enabled = true,
	speed = 4,
	bezier = "myBezier",
	style = "popin 80%",
})
hl.animation({
	leaf = "windowsOut",
	enabled = true,
	speed = 4,
	bezier = "myBezier",
	style = "popin 80%",
})
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({
	leaf = "layersIn",
	enabled = true,
	speed = 4,
	bezier = "myBezier",
	style = "popin 90%",
})
hl.animation({
	leaf = "layersOut",
	enabled = true,
	speed = 4,
	bezier = "myBezier",
	style = "popin 90%",
})
hl.animation({ leaf = "layersOut", enabled = true, speed = 3, bezier = "almostLinear" })

hl.animation({
	leaf = "fadeLayersIn",
	enabled = true,
	speed = 1.79,
	bezier = "almostLinear",
})
hl.animation({
	leaf = "fadeLayersOut",
	enabled = true,
	speed = 1.39,
	bezier = "almostLinear",
})
hl.animation({
	leaf = "workspaces",
	enabled = true,
	speed = 5,
	bezier = "quick",
	style = "slidevert",
})
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 5, bezier = "quick" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 5, bezier = "quick" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })
hl.animation({
	leaf = "specialWorkspaceIn",
	enabled = true,
	speed = 5,
	bezier = "default",
	style = "slide bottom",
})
hl.animation({
	leaf = "specialWorkspaceOut",
	enabled = true,
	speed = 5,
	bezier = "default",
	style = "slide top",
})
