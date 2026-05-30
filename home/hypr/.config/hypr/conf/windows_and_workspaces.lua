local programs = require("conf.programs")

------------------------
---- GLOBAL FIXES ------
------------------------

local suppressMaximizeRule = hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})
suppressMaximizeRule:set_enabled(true)

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
	move = "20 95%",
	float = true,
})

---------------------------------
---- SPECIAL WORKSPACE APPS -----
---------------------------------

local focusGaps = { top = 54, right = 96, bottom = 54, left = 96 }

-- Zamiast regexów ".*[Dd]iscord.*", używamy dokładnych klas Waylanda
local specialApps = {
	{ class = "discord", workspace = "special:discord", exe = programs.discord },
	{ class = "Spotify", workspace = "special:spotify", exe = programs.spotify },
}

for _, app in ipairs(specialApps) do
	hl.workspace_rule({
		workspace = app.workspace,
		on_created_empty = app.exe,
		gaps_out = focusGaps,
		gaps_in = 0,
	})

	hl.window_rule({
		match = { class = app.class },
		workspace = app.workspace,
	})
end

hl.workspace_rule({
	workspace = "special:focus",
	gaps_out = focusGaps,
	gaps_in = 0,
})

-------------------------
---- FLOATING APPS ------
-------------------------

local floatingRules = {
	["600 400"] = {
		{ class = "org.gnome.Calculator" },
		{ class = "com.saivert.pwvucontrol" },
		{ class = "org.gnome.clocks" },
		{ class = "blueman-manager" },
	},
	["1500 900"] = {
		{ class = "loupe" },
		{ class = "showtime" },
		{ class = "snapshot" },
		{ title = "yazi-float" },
		{ title = "btop-float" },
		{ title = "bluetui-float" },
		{ title = "impala-float" },
	},
}

for size, apps in pairs(floatingRules) do
	for _, appMatch in ipairs(apps) do
		hl.window_rule({
			match = appMatch,
			float = true,
			center = true,
			size = size,
		})
	end
end
