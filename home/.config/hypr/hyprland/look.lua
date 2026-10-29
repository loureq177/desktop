-- Colours, sizes and the theme come from ui.lua, which apply-ui renders from
-- ui.toml for the shell and the apps as well.

local ui = require("ui")

hl.config({
	general = {
		gaps_in = ui.spacing.gaps_in,
		gaps_out = ui.spacing.gaps_out,
		border_size = ui.border.size,
		col = {
			active_border = {
				colors = { ui.colors.accent_blue, ui.colors.accent_purple },
				angle = 45,
			},
			inactive_border = ui.colors.border,
		},
		resize_on_border = true,
		snap = {
			enabled = true,
		},
	},
	decoration = {
		rounding = ui.rounding.window,
		rounding_power = ui.rounding.power,
		active_opacity = ui.opacity.active,
		inactive_opacity = ui.opacity.inactive,
		dim_inactive = true,
		dim_strength = 0.15,
		dim_special = ui.opacity.dim_special,
		shadow = {
			range = 16,
			render_power = 4,
			color = ui.colors.shadow,
		},
		blur = {
			passes = 3,
			-- live (non-xray) blur halves the frame rate on outputs driven through the multi-GPU blit
			xray = true,
			vibrancy = 0.4,
			noise = 0.02,
		},
	},
	dwindle = {
		preserve_split = true,
	},
	xwayland = {
		enabled = false,
	},
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		focus_on_activate = true,
		key_press_enables_dpms = true,
		mouse_move_enables_dpms = true,
		allow_session_lock_restore = true,
	},
})

-- The shell drawers' curve and time, no overshoot (a resizing client would draw
-- twice).
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

for _, animation in ipairs({
	{ leaf = "global", speed = 10, bezier = "default" },
	{ leaf = "border", speed = 3, bezier = "easeOutQuint" },
	{ leaf = "windows", speed = 3, bezier = "easeOutQuint" },
	{ leaf = "windowsIn", speed = 3, bezier = "easeOutQuint", style = "popin 80%" },
	{ leaf = "windowsOut", speed = 3, bezier = "easeOutQuint", style = "popin 85%" },
	{ leaf = "fadeIn", speed = 1.73, bezier = "almostLinear" },
	{ leaf = "fadeOut", speed = 1.46, bezier = "almostLinear" },
	{ leaf = "fade", speed = 4, bezier = "default" },
	{ leaf = "layersIn", speed = 1.79, bezier = "almostLinear", style = "fade" },
	{ leaf = "layersOut", speed = 1.39, bezier = "almostLinear", style = "fade" },
	{ leaf = "fadeLayersIn", speed = 1.79, bezier = "almostLinear" },
	{ leaf = "fadeLayersOut", speed = 1.39, bezier = "almostLinear" },
	{ leaf = "workspacesIn", speed = 3, bezier = "easeOutQuint" },
	{ leaf = "workspacesOut", speed = 3, bezier = "easeOutQuint" },
	{ leaf = "zoomFactor", speed = 7, bezier = "quick" },
	{ leaf = "specialWorkspaceIn", speed = 4, bezier = "default", style = "slide bottom" },
	{ leaf = "specialWorkspaceOut", speed = 4, bezier = "default", style = "slide top" },
}) do
	animation.enabled = true
	hl.animation(animation)
end

hl.layer_rule({
	name = "no-anim-capture",
	match = { namespace = "^(hyprpicker|selection)$" },
	no_anim = true,
})
hl.layer_rule({
	name = "no-anim-wallpaper",
	match = { namespace = "^wallpaper$" },
	no_anim = true,
})
hl.layer_rule({
	name = "blur-shell-panels",
	match = { namespace = "^quickshell$" },
	blur = true,
	-- the tray's menus, which open from the bar
	blur_popups = true,
	-- the shell animates its own panels; Hyprland's fade on top shows the
	-- card unblurred for a moment and freezes its last frame on the way out
	no_anim = true,
	-- above the backdrop dim, so only the panels themselves get frosted
	ignore_alpha = 0.5,
})
