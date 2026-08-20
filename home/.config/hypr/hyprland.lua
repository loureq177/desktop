-- ─── Programs ────────────────────────────────────────────────────────────────

local bin = os.getenv("HOME") .. "/.local/bin"
local hypr = os.getenv("HOME") .. "/.config/hypr"

local programs = {
	terminal = "ghostty",
	browser = "firefox",
	launcher = "rofi -show drun -replace",

	special = {
		discord = { exe = "discord", class = "discord", ws = "discord" },
		spotify = { exe = "flatpak run com.spotify.Client", class = "spotify", ws = "spotify" },
		tasks = { exe = bin .. "/tasks", class = "tasks", ws = "tasks" },
		calendar = { exe = bin .. "/calendar", class = "calendar", ws = "calendar" },
		mail = { exe = bin .. "/gmail", class = "gmail", ws = "mail" },
		gemini = { exe = bin .. "/gemini", class = "gemini", ws = "gemini" },
		whatsapp = { exe = bin .. "/whatsapp", class = "whatsapp", ws = "whatsapp" },
		yazi = { exe = "ghostty --class=yazi -e yazi", class = "yazi", ws = "yazi" },
		bluetui = { exe = "ghostty --class=bluetui -e bluetui", class = "bluetui", ws = "bluetui" },
		jolt = { exe = "ghostty --class=jolt -e jolt", class = "jolt", ws = "jolt" },
		impala = { exe = "ghostty --class=impala -e impala", class = "impala", ws = "impala" },
		btop = { exe = "ghostty --class=btop -e btop", class = "btop", ws = "btop" },
		nvtop = { exe = "ghostty --class=nvtop -e nvtop", class = "nvtop", ws = "nvtop" },
		clipboard = {
			exe = hypr .. "/scripts/cliphist-paste.sh",
			class = "clipboard-special",
			ws = "clipboard",
		},
	},
}

-- ─── Environment ─────────────────────────────────────────────────────────────

hl.env("AQ_DRM_DEVICES", "/dev/dri/amd-igpu:/dev/dri/nvidia-dgpu")
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("SAL_USE_VCLPLUGIN", "gtk3")

-- ─── Autostart ───────────────────────────────────────────────────────────────

local gsettings = "gsettings set org.gnome.desktop.interface"

hl.on("hyprland.start", function()
	local cmds = {
		gsettings .. " icon-theme 'Papirus-Dark'",
		gsettings .. " font-name 'Adwaita Sans 12'",
		gsettings .. " color-scheme 'prefer-dark'",
		gsettings .. " gtk-theme 'Adwaita-dark'",
		gsettings .. " monospace-font-name 'JetBrainsMono Nerd Font Mono 12'",

		"dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE",
		"systemctl --user start hyprland-session.target",

		"wl-paste --type text --watch cliphist -max-items 50 store",
		"wl-paste --type image/png --watch cliphist -max-items 10 store",
		"wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.25",
		"waybar",
		"swaybg -i ~/.config/hypr/wallpapers/hyprland.png",
		"swaync",
		"hyprsunset",
	}

	for _, cmd in ipairs(cmds) do
		hl.exec_cmd(cmd)
	end
end)

-- ─── Monitors ────────────────────────────────────────────────────────────────

local laptop_output = "desc:BOE 0x0998"
local laptop_mode = "1920x1080@165"
local laptop_pos = "320x1440"
local laptop_scale = 1

local external_output = "desc:Iiyama North America PL2792Q 1152011401936"

hl.monitor({
	output = laptop_output,
	mode = laptop_mode,
	position = laptop_pos,
	scale = laptop_scale,
})
hl.monitor({
	output = external_output,
	mode = "2560x1440@59.95",
	position = "0x0",
	scale = 1,
})
hl.monitor({
	output = "DP-1",
	mode = "2560x1440@59.95",
	position = "0x0",
	scale = 1,
})
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = 1,
})

hl.bind("switch:on:Lid Switch", function()
	local mons = hl.get_monitors()
	if #mons > 1 then
		hl.dsp.dpms({ action = "off", monitor = laptop_output })
	end
end, { locked = true })

hl.bind("switch:off:Lid Switch", function()
	hl.dsp.dpms({ action = "on" })
end, { locked = true })

-- ─── Input & Gestures ────────────────────────────────────────────────────────

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
		sensitivity = 0.2,
		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
		},
	},
	cursor = {
		inactive_timeout = 0,
		warp_on_change_workspace = true,
	},
	gestures = {
		workspace_swipe_touch = true,
		workspace_swipe_cancel_ratio = 0.05,
	},
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- ─── Look & Feel ─────────────────────────────────────────────────────────────

local colors = {
	accent_blue = "rgba(58a6ffee)",
	accent_purple = "rgba(bc8cffee)",
	inactive_border = "rgba(30363dee)",
}

hl.config({
	general = {
		gaps_in = 10,
		gaps_out = 20,
		border_size = 2,
		col = {
			active_border = {
				colors = { colors.accent_blue, colors.accent_purple },
				angle = 45,
			},
			inactive_border = colors.inactive_border,
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
			range = 4,
			render_power = 3,
			color = "0xee1a1a1a",
		},
		blur = {
			size = 6,
			passes = 2,
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

local original_animation = hl.animation
hl.animation = function(config)
	if config.enabled == nil then
		config.enabled = true
	end
	original_animation(config)
end

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", speed = 10, bezier = "default" })
hl.animation({ leaf = "border", speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", speed = 4, bezier = "myBezier" })
hl.animation({ leaf = "windowsIn", speed = 4, bezier = "myBezier", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", speed = 4, bezier = "myBezier", style = "popin 80%" })
hl.animation({ leaf = "fadeIn", speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", speed = 4, bezier = "default" })
hl.animation({ leaf = "layers", speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", speed = 4, bezier = "myBezier", style = "popin 90%" })
hl.animation({ leaf = "layersOut", speed = 4, bezier = "myBezier", style = "popin 90%" })
hl.animation({ leaf = "fadeLayersIn", speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", speed = 5, bezier = "quick", style = "slidevert" })
hl.animation({ leaf = "workspacesIn", speed = 3, bezier = "quick" })
hl.animation({ leaf = "workspacesOut", speed = 3, bezier = "quick" })
hl.animation({ leaf = "zoomFactor", speed = 7, bezier = "quick" })
hl.animation({ leaf = "specialWorkspaceIn", speed = 4, bezier = "default", style = "slide bottom" })
hl.animation({ leaf = "specialWorkspaceOut", speed = 4, bezier = "default", style = "slide top" })

-- ─── Misc ────────────────────────────────────────────────────────────────────

hl.config({
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		focus_on_activate = true,
		key_press_enables_dpms = true,
		mouse_move_enables_dpms = true,
		vrr = 0,
	},
})

-- ─── Windows & Workspaces ────────────────────────────────────────────────────

hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
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

for _, app in pairs(programs.special) do
	local ws = "special:" .. app.ws
	hl.workspace_rule({
		workspace = ws,
		on_created_empty = app.exe,
		gaps_out = 75,
	})
	hl.window_rule({ match = { class = app.class }, workspace = ws })
end

hl.window_rule({
	name = "picture-in-picture",
	match = { title = "^(Picture-in-Picture|Obraz w obrazie)$" },
	float = true,
	pin = true,
})

for i = 1, 3 do
	hl.workspace_rule({ workspace = tostring(i), monitor = external_output })
end
for i = 4, 6 do
	hl.workspace_rule({ workspace = tostring(i), monitor = laptop_output })
end

hl.window_rule({
	match = {
		class = "^(org.gnome.*|com.saivert.pwvucontrol|pavucontrol|nm-connection-editor|blueman-manager|xdg-desktop-portal-gtk|file-roller)$",
	},
	float = true,
	center = true,
})

-- ─── Keybindings ─────────────────────────────────────────────────────────────

local cmds = {
	["SUPER + RETURN"] = programs.terminal,
	["SUPER + B"] = programs.browser,
	["SUPER + space"] = programs.launcher,
	["SUPER + Period"] = "rofi -show emoji -modi emoji -emoji-mode copy",

	["SUPER + CTRL + Q"] = "loginctl lock-session",
	["SUPER + CTRL + A"] = "swaync-client -t",
	["SUPER + CTRL + R"] = "~/.config/hypr/scripts/record-screen.sh",
	["SUPER + CTRL + M"] = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && pkill -RTMIN+8 waybar",
	["SUPER + CTRL + P"] = "hyprpicker -a --notify",
	["SUPER + CTRL + space"] = "rofi -show run -replace",

	["Print"] = "~/.config/hypr/scripts/screenshot.sh region",
	["SHIFT + Print"] = "~/.config/hypr/scripts/screenshot.sh fullscreen",
	["SUPER + Escape"] = "~/.config/hypr/scripts/powermenu.sh",
}

for bind, cmd in pairs(cmds) do
	hl.bind(bind, hl.dsp.exec_cmd(cmd))
end

local special_apps = {
	["SUPER + C"] = "calendar",
	["SUPER + T"] = "tasks",
	["SUPER + W"] = "whatsapp",
	["SUPER + M"] = "mail",
	["SUPER + D"] = "discord",
	["SUPER + S"] = "spotify",
	["SUPER + A"] = "gemini",
	["SUPER + E"] = "yazi",
	["SUPER + CTRL + C"] = "clipboard",
	["SUPER + CTRL + B"] = "bluetui",
	["SUPER + CTRL + I"] = "impala",
	["SUPER + CTRL + Escape"] = "btop",
}

for bind, app in pairs(special_apps) do
	hl.bind(bind, hl.dsp.workspace.toggle_special(programs.special[app].ws))
end

hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + P", hl.dsp.window.pseudo())
hl.bind("SUPER + SHIFT + T", hl.dsp.layout("togglesplit"))

local directions = { H = "left", L = "right", K = "up", J = "down" }
local step = 50

for key, dir in pairs(directions) do
	hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = dir }))
	hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }))

	hl.bind(
		"SUPER + CTRL + " .. key,
		hl.dsp.window.resize({
			x = (dir == "left" and -step) or (dir == "right" and step) or 0,
			y = (dir == "up" and -step) or (dir == "down" and step) or 0,
			relative = true,
		}),
		{ repeating = true }
	)
end

for i = 1, 9 do
	hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

local vol = "wpctl set-volume"

local media = {
	{ "XF86AudioRaiseVolume", vol .. " -l 1.0 @DEFAULT_AUDIO_SINK@ 2%+", true },
	{ "XF86AudioLowerVolume", vol .. " -l 1.0 @DEFAULT_AUDIO_SINK@ 2%-", true },
	{ "XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
	{ "XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" },
	{ "XF86MonBrightnessUp", "brightnessctl set +10%", true },
	{ "XF86MonBrightnessDown", "brightnessctl set 10%-", true },
}

for _, m in ipairs(media) do
	hl.bind(m[1], hl.dsp.exec_cmd(m[2]), { locked = true, repeating = m[3] })
end
