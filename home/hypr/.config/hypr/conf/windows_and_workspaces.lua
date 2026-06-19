local programs = require("conf.programs")

-- ─── Global Fixes ────────────────────────────────────────────────────────────

hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})
hl.window_rule({
	name = "fix-xwayland-drags",
	match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
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
	move = "20 monitor_h-120",
	float = true,
})

-- ─── Special Workspaces ──────────────────────────────────────────────────────

for _, app in pairs(programs.special) do
	local ws = "special:" .. app.ws
	hl.workspace_rule({ workspace = ws, on_created_empty = app.exe })
	hl.window_rule({ match = { class = app.class }, workspace = ws })
end

for _, app in pairs(programs.scratchpad) do
	hl.window_rule({ match = { class = app.class }, workspace = "special:scratchpad" })
end

local function applyFocusGaps(monitor)
	local gH = math.floor(monitor.height * 0.075)
	local gW = math.floor(monitor.width * 0.075)
	local gaps = { top = gH, right = gW, bottom = gH, left = gW }

	for _, app in pairs(programs.special) do
		hl.workspace_rule({ workspace = "special:" .. app.ws, gaps_out = gaps, gaps_in = 0 })
	end
	hl.workspace_rule({ workspace = "special:scratchpad", gaps_out = gaps, gaps_in = 0 })
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

-- ─── Floating Apps ───────────────────────────────────────────────────────────

hl.window_rule({
	match = {
		class = "^(org.gnome.Calculator|com.saivert.pwvucontrol|org.gnome.clocks|org.gnome.Loupe|org.gnome.Showtime|org.gnome.Snapshot)$",
	},
	float = true,
	center = true,
})
hl.window_rule({
	match = { class = "^(bluetui|impala|btop)$" },
})
hl.window_rule({
	name = "clipboard-float",
	match = { initial_title = "^Clipboard$" },
	float = true,
	center = true,
	size = "monitor_w*0.45 monitor_h*0.4",
})
hl.layer_rule({
	name = "clipboard-blur",
	match = { initial_title = "^Clipboard$" },
	blur = true,
	ignore_alpha = 0.2,
})
