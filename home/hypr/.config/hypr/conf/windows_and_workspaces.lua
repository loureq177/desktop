local programs = require("conf.programs")

-- ─── Global Fixes ────────────────────────────────────────────────────────────

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
	name = "blur-layer-popups",
	match = { namespace = "^(rofi|swaync-control-center)$" },
	blur = true,
	ignore_alpha = 0.2,
})
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})

-- ─── Special Workspaces ─────────────────────────────────────────────────────

for _, app in pairs(programs.special) do
	local ws = "special:" .. app.ws
	hl.workspace_rule({
		workspace = ws,
		on_created_empty = app.exe,
		gaps_out = 75,
	})
	hl.window_rule({ match = { class = app.class }, workspace = ws })
end

-- ─── Floating Apps ───────────────────────────────────────────────────────────

hl.window_rule({
	match = {
		class = "^(org.gnome.*|com.saivert.pwvucontrol)$",
	},
	float = true,
	center = true,
})
