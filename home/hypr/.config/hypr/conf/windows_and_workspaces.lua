local programs = require("conf.programs")

------------------------
---- GLOBAL FIXES ------
------------------------

hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
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

hl.layer_rule({
	name = "rofi-blur",
	match = { namespace = "^rofi$" },
	blur = true,
	ignore_alpha = 0.2,
})

hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h*0.95",
	float = true,
})

---------------------------------
---- SPECIAL WORKSPACE APPS -----
---------------------------------

local specialApps = {
	{ match = { class = "discord" }, workspace = "special:discord", exe = programs.discord },
	{ match = { class = "Spotify" }, workspace = "special:spotify", exe = programs.spotify },
	{ match = { initial_title = "^btop$" }, workspace = "special:btop", exe = programs.btop },
}

local specialWorkspaces = {
	"special:discord",
	"special:spotify",
	"special:btop",
	"special:focus",
}

for _, app in ipairs(specialApps) do
	hl.workspace_rule({
		workspace = app.workspace,
		on_created_empty = app.exe,
	})
	hl.window_rule({
		match = app.match,
		workspace = app.workspace,
	})
end

-- dynamiczne gapy: 85% ekranu niezależnie od rozdzielczości
local function applyFocusGaps(monitor)
	local gapV = math.floor(monitor.height * 0.075)
	local gapH = math.floor(monitor.width * 0.075)
	local gaps = { top = gapV, right = gapH, bottom = gapV, left = gapH }

	for _, ws in ipairs(specialWorkspaces) do
		hl.workspace_rule({
			workspace = ws,
			gaps_out = gaps,
			gaps_in = 0,
		})
	end
end

for _, monitor in ipairs(hl.get_monitors()) do
	applyFocusGaps(monitor)
end

hl.on("monitor.added", applyFocusGaps)
hl.on("monitor.removed", function(_)
	for _, monitor in ipairs(hl.get_monitors()) do
		applyFocusGaps(monitor)
	end
end)

-------------------------
---- FLOATING APPS ------
-------------------------

hl.window_rule({
	match = {
		class = "^(org.gnome.Calculator|com.saivert.pwvucontrol|org.gnome.clocks|org.gnome.Loupe|org.gnome.Showtime|org.gnome.Snapshot)$",
	},
	float = true,
	center = true,
})

hl.window_rule({
	match = { initial_title = "^(yazi|bluetui|impala)-float$" },
	float = true,
	center = true,
	size = "monitor_w*0.8 monitor_h*0.8",
})
