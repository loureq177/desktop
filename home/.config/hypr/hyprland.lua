-- ─── Programs ────────────────────────────────────────────────────────────────

local bin = os.getenv("HOME") .. "/.local/bin"
local hypr = os.getenv("HOME") .. "/.config/hypr"

local ui_ok, ui = pcall(dofile, hypr .. "/ui.lua")
if not ui_ok then
	ui = {
		rounding = { window = 0, element = 0, subtle = 0 },
		border = { size = 2 },
		spacing = { gaps_in = 10, gaps_out = 20 },
		opacity = { active = 1.0, inactive = 0.96 },
		theme = { cursor = "Bibata-Modern-Classic", icon = "Papirus-Dark", gtk = "Adwaita-dark" },
		font = {
			family = "JetBrainsMono Nerd Font Propo",
			mono = "JetBrainsMono Nerd Font Mono",
			ui = "Adwaita Sans 12",
			size_cursor = 24,
		},
		colors = {
			border = "rgba(30363dee)",
			accent_blue = "rgba(58a6ffee)",
			accent_purple = "rgba(bc8cffee)",
			shadow = "rgba(010409ee)",
		},
	}
end

local local_ok, local_cfg = pcall(dofile, hypr .. "/local.lua")
if not local_ok or type(local_cfg) ~= "table" then
	local_cfg = {}
end

local programs = {
	terminal = "ghostty",
	browser = "firefox",
	launcher = "qs ipc call shell toggle launcher apps",

	special = {
		-- Apps
		spotify = { exe = "flatpak run com.spotify.Client", class = "spotify", ws = "spotify" },
		tasks = {
			exe = bin .. "/firefox-webapp tasks https://tasks.google.com",
			class = "webapps",
			title = ".*Tasks.*",
			ws = "tasks",
		},
		calendar = {
			exe = bin .. "/firefox-webapp calendar https://calendar.google.com",
			class = "webapps",
			title = ".*Calendar.*",
			ws = "calendar",
		},
		mail = {
			exe = bin .. "/firefox-webapp gmail https://mail.google.com",
			class = "webapps",
			title = ".*Gmail.*",
			ws = "mail",
		},
		gemini = {
			exe = bin .. "/firefox-webapp gemini https://gemini.google.com",
			class = "webapps",
			title = ".*Gemini.*",
			ws = "gemini",
		},
		whatsapp = {
			exe = bin .. "/firefox-webapp whatsapp https://web.whatsapp.com",
			class = "webapps",
			title = ".*WhatsApp.*",
			ws = "whatsapp",
		},
		yazi = { exe = "ghostty --class=yazi -e yazi", class = "yazi", ws = "yazi" },

		-- System tools
		audio = {
			exe = "pwvucontrol --tab 4",
			class = "com.saivert.pwvucontrol",
			ws = "pwvucontrol",
		},
		calculator = {
			exe = "gnome-calculator",
			class = "org.gnome.Calculator",
			ws = "gnome-calculator",
		},
		jolt = { exe = "ghostty --class=jolt -e jolt", class = "jolt", ws = "jolt" },
		btop = { exe = "ghostty --class=btop -e btop", class = "btop", ws = "btop" },
	},
}

-- ─── Environment ─────────────────────────────────────────────────────────────

if type(local_cfg.env) == "function" then
	local_cfg.env()
end

hl.env("GSK_RENDERER", "gl")
hl.env("GTK_A11Y", "none")
hl.env("XDG_SESSION_TYPE", "wayland")
for _, var in ipairs({ "XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP" }) do
	hl.env(var, "Hyprland")
end
hl.env("GDK_BACKEND", "wayland,x11")
-- Ghostty ≥1.2 (GTK) binds ext_background_effect_manager_v1 and Hyprland
-- then defers backdrop-blur decisions to the client, which requests nothing
-- (background-blur=false) — net effect: no blur behind Ghostty, only flat
-- transparency. Disabling the protocol forces classic compositor-side
-- decoration blur. Cf. r/hyprland "ghostty blur not working" (Oct 2026).
-- Requires full Ghostty restart (single-instance: env is read once at
-- process start, new windows join the old process).
hl.env("GDK_WAYLAND_DISABLE", "ext_background_effect_manager_v1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QS_ICON_THEME", ui.theme.icon)
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
for _, prefix in ipairs({ "XCURSOR", "HYPRCURSOR" }) do
	hl.env(prefix .. "_THEME", ui.theme.cursor)
	hl.env(prefix .. "_SIZE", tostring(ui.font.size_cursor))
end
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("SAL_USE_VCLPLUGIN", "gtk3")

-- ─── Autostart ───────────────────────────────────────────────────────────────

local function gset(key, val)
	return string.format("gsettings set org.gnome.desktop.interface %s '%s'", key, val)
end

hl.on("hyprland.start", function()
	-- Singleton guards: hyprland.start can re-fire on reload. Bare starts
	-- would stack a second wl-paste watcher (double cliphist store), a
	-- second quickshell and a second hyprsunset per reload.
	local cmds = {
		gset("cursor-theme", ui.theme.cursor),
		gset("icon-theme", ui.theme.icon),
		gset("font-name", ui.font.ui),
		gset("color-scheme", "prefer-dark"),
		gset("gtk-theme", ui.theme.gtk),
		gset("monospace-font-name", ui.font.mono .. " 12"),

		"dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE AQ_DRM_DEVICES VK_DRIVER_FILES VK_ICD_FILENAMES LIBVA_DRIVER_NAME GSK_RENDERER QT_QPA_PLATFORM SDL_VIDEODRIVER CLUTTER_BACKEND MOZ_ENABLE_WAYLAND ELECTRON_OZONE_PLATFORM_HINT",
		"systemctl --user start hyprland-session.target",

		"sh -c 'pgrep -f \"[w]l-paste --type text\" >/dev/null || wl-paste --type text --watch cliphist -max-items 100 store'",
		"sh -c 'pgrep -f \"[w]l-paste --type image\" >/dev/null || wl-paste --type image/png --watch cliphist -max-items 100 store'",
		"wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.25",
		"~/.local/bin/wallpaper init",
		-- Reassert patched 74Hz on the iiyama if the EDID override landed
		-- late (hotplug race / dGPU D3cold resume). No-op when undocked or
		-- already at 74Hz; never forces an unadvertised mode (panic-safe).
		"~/.local/bin/ensure-74hz",
		"sh -c 'pidof quickshell >/dev/null || quickshell -d'",
		"sh -c 'pidof hyprsunset >/dev/null || hyprsunset'",
	}

	for _, cmd in ipairs(cmds) do
		hl.exec_cmd(cmd)
	end
end)

-- ─── Monitors ────────────────────────────────────────────────────────────────

if type(local_cfg.monitors) == "function" then
	local_cfg.monitors()
end

hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = 1,
})

-- ─── Workspaces: keep numeric IDs compact (1..N) across topology changes ──
-- Root cause of the "2,3 instead of 1,2 after lid-close" bug: lid-close only
-- blanked eDP (dpms off) while keeping it enabled, so its (empty) workspace
-- kept its number alive as a ghost. Fix: disable eDP when an external
-- monitor exists (Hyprland then evacuates windows to the remaining monitors
-- and destroys eDP's empty workspaces), re-enable on lid-open by
-- re-applying the local.lua monitor specs. compact_workspaces() below is a
-- safety net for leftover gaps (dock/undock, pre-existing gaps, races): it
-- renumbers numeric workspaces to 1..N preserving order, focus and monitor
-- assignment. Special and named workspaces are untouched. It runs ONLY on
-- topology changes (lid, monitor added/removed), never on normal workspace
-- open/close, so SUPER+1..9 muscle memory stays stable.

local compacting = false
local compact_gen = 0

local function is_compactable_ws(ws)
	if ws == nil or ws.special then
		return false
	end
	local id = ws.id
	if type(id) ~= "number" or id < 1 or id ~= math.floor(id) then
		return false
	end
	if not tostring(ws.name or ""):match("^%d+$") then
		return false
	end
	return true
end

local function compact_workspaces()
	if compacting then
		return
	end
	compacting = true
	pcall(function()
		local all = hl.get_workspaces and hl.get_workspaces() or {}
		local nums = {}
		for _, ws in ipairs(all) do
			if is_compactable_ws(ws) then
				table.insert(nums, ws)
			end
		end
		if #nums == 0 then
			return
		end
		table.sort(nums, function(a, b)
			return a.id < b.id
		end)
		local active = hl.get_active_workspace and hl.get_active_workspace() or nil
		local focused_old = active ~= nil and active.id or nil
		local focused_new = focused_old
		for idx, ws in ipairs(nums) do
			if ws.id ~= idx then
				-- Compacting down in ascending order guarantees the target
				-- is free (idx <= ws.id, lower IDs already claimed). If a
				-- race occupied it, skip: the next topology event retries.
				local target = hl.get_workspace and hl.get_workspace(idx) or nil
				if target == nil then
					hl.dispatch(hl.dsp.workspace.change_id({ workspace = ws.id, id = idx }))
					if focused_old == ws.id then
						focused_new = idx
					end
				end
			end
		end
		if focused_new ~= nil and focused_new ~= focused_old then
			pcall(function()
				hl.dispatch(hl.dsp.focus({ workspace = focused_new }))
			end)
		end
	end)
	compacting = false
end

local function schedule_compact(ms)
	compact_gen = compact_gen + 1
	local gen = compact_gen
	hl.timer(function()
		if gen ~= compact_gen then
			return
		end
		compact_workspaces()
	end, { timeout = ms or 500, type = "oneshot" })
end

local function find_edp()
	for _, m in ipairs(hl.get_monitors()) do
		if (m.name or ""):find("^eDP") then
			return m
		end
	end
	return nil
end

local function has_external_monitor(edp_name)
	for _, m in ipairs(hl.get_monitors()) do
		if m.name ~= edp_name then
			return true
		end
	end
	return false
end

if local_cfg.lid_switch ~= false and not local_cfg.custom_lid_switch then
	local last_edp_output = nil
	hl.bind("switch:on:Lid Switch", function()
		local edp = find_edp()
		if edp == nil then
			return
		end
		last_edp_output = edp.name
		if has_external_monitor(edp.name) then
			-- Disable, not just dpms off: Hyprland evacuates windows from
			-- eDP to the remaining monitors and destroys its empty
			-- workspaces, so no ghost number is kept alive. Windows stay
			-- grouped on their workspace; only the workspace changes
			-- monitor. Empty eDP workspaces simply die (that's what frees
			-- the number: 1,2,3 -> 1,2).
			hl.monitor({ output = edp.name, disabled = true })
		else
			-- Sole monitor (on the go): only blank, suspend is handled by
			-- hypridle/systemd. Never disable the last screen.
			hl.dispatch(hl.dsp.dpms({ action = "off", monitor = edp.name }))
		end
		schedule_compact(500)
	end, { locked = true })

	hl.bind("switch:off:Lid Switch", function()
		hl.dispatch(hl.dsp.dpms({ action = "on" }))
		-- Re-apply local.lua monitor specs: re-enables eDP with its
		-- mode/position/scale. Hyprland gives it the next free workspace
		-- number, so there is no renumbering fight. Evacuated windows stay
		-- where they are (predictable); move them back manually with
		-- SUPER+SHIFT+<num> when needed.
		if type(local_cfg.monitors) == "function" then
			local ok = pcall(local_cfg.monitors)
			if not ok and last_edp_output ~= nil then
				-- Fallback: at least re-enable by connector name.
				pcall(hl.monitor, { output = last_edp_output, disabled = false })
			end
		end
		schedule_compact(800)
	end, { locked = true })

	-- Dock/undock (dwie HP-ki, iiyama) goes through the same path:
	-- Hyprland evacuates/creates, we only fix leftover number gaps.
	hl.on("monitor.added", function()
		schedule_compact(500)
	end)
	hl.on("monitor.removed", function()
		schedule_compact(500)
	end)
end

-- ─── Input & Gestures ────────────────────────────────────────────────────────

hl.config({
	input = {
		kb_layout = "pl",
		kb_variant = "",
		kb_model = "",
		kb_options = "altwin:swap_lalt_lwin",
		kb_rules = "",
		repeat_delay = 200,
		repeat_rate = 20,
		follow_mouse = 1,
		sensitivity = 0.2,
		scroll_factor = 0.3,
		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
			scroll_factor = 0.5,
		},
	},
	cursor = {
		inactive_timeout = 0,
		warp_on_change_workspace = true,
		enable_hyprcursor = true,
		sync_gsettings_theme = true,
	},
	gestures = {
		workspace_swipe_touch = true,
		workspace_swipe_cancel_ratio = 0.02,
	},
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- ─── Special workspace swipe ────────────────────────────────────────────────

local special_gesture_mode = nil -- "down", "up" or nil
local special_gesture_name = nil
local special_history = {}
local special_cycle_active = false

local function special_short_name(ws)
	if ws == nil then
		return nil
	end
	local name = (ws.name or ""):gsub("^special:", "")
	if name == "" then
		return nil
	end
	return name
end

local function visible_special_workspace()
	local mon = hl.get_active_monitor()
	if mon ~= nil and mon.active_special_workspace ~= nil then
		return mon.active_special_workspace
	end
	for _, m in ipairs(hl.get_monitors()) do
		if m.active_special_workspace ~= nil then
			return m.active_special_workspace
		end
	end
	return nil
end

local function set_special_gesture(mode, name)
	if mode == special_gesture_mode and name == special_gesture_name then
		return
	end
	if special_gesture_mode ~= nil then
		hl.gesture({ fingers = 3, direction = special_gesture_mode, action = "unset" })
	end
	special_gesture_mode = nil
	special_gesture_name = nil
	if mode ~= nil and name ~= nil then
		hl.gesture({ fingers = 3, direction = mode, action = "special", workspace_name = name })
		special_gesture_mode = mode
		special_gesture_name = name
	end
end

local function list_open_specials()
	local seen = {}
	local ordered = {}
	local function push(name)
		if name == nil or seen[name] then
			return
		end
		local target = hl.get_workspace("special:" .. name)
		if target ~= nil and not target.is_empty then
			seen[name] = true
			table.insert(ordered, name)
		end
	end
	local wins = hl.get_windows()
	local function focus_age(w)
		local id = w.focus_history_id
		if id == nil or id < 0 then
			return math.huge
		end
		return id
	end
	table.sort(wins, function(a, b)
		return focus_age(a) < focus_age(b)
	end)
	for _, w in ipairs(wins) do
		if w.workspace ~= nil and w.workspace.special then
			push(special_short_name(w.workspace))
		end
	end
	for _, name in ipairs(special_history) do
		push(name)
	end
	if hl.get_workspaces ~= nil then
		for _, ws in ipairs(hl.get_workspaces()) do
			if ws.special then
				push(special_short_name(ws))
			end
		end
	end
	return ordered
end

local function cycle_special(delta)
	local visible = special_short_name(visible_special_workspace())
	if visible == nil then
		return
	end
	local list = list_open_specials()
	if #list < 2 then
		return
	end
	table.sort(list)
	local idx = 1
	for i, name in ipairs(list) do
		if name == visible then
			idx = i
			break
		end
	end
	local target = list[((idx - 1 + delta) % #list) + 1]
	for i, name in ipairs(special_history) do
		if name == target then
			table.remove(special_history, i)
			break
		end
	end
	table.insert(special_history, 1, target)
	hl.dispatch(hl.dsp.workspace.toggle_special(target))
end

local function cycle_special_next()
	cycle_special(1)
end

local function cycle_special_prev()
	cycle_special(-1)
end

-- While a special workspace is visible, horizontal motion cycles specials
local function set_cycle_gestures(enabled)
	if enabled == special_cycle_active then
		return
	end
	if special_cycle_active then
		hl.gesture({ fingers = 3, direction = "left", action = "unset" })
		hl.gesture({ fingers = 3, direction = "right", action = "unset" })
		hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
		special_cycle_active = false
	end
	if enabled then
		hl.gesture({ fingers = 3, direction = "horizontal", action = "unset" })
		hl.gesture({ fingers = 3, direction = "left", action = cycle_special_next })
		hl.gesture({ fingers = 3, direction = "right", action = cycle_special_prev })
		special_cycle_active = true
	end
end

local function refresh_special_gestures()
	special_history = list_open_specials()
	local visible = special_short_name(visible_special_workspace())
	if visible ~= nil then
		for i, name in ipairs(special_history) do
			if name == visible then
				table.remove(special_history, i)
				break
			end
		end
		table.insert(special_history, 1, visible)
		set_special_gesture("down", visible)
	else
		set_special_gesture("up", special_history[1])
	end
	set_cycle_gestures(visible ~= nil)
end

hl.on("workspace.special_active", function()
	refresh_special_gestures()
end)
hl.on("workspace.active", function()
	refresh_special_gestures()
end)
hl.on("window.active", function()
	refresh_special_gestures()
end)
hl.on("window.close", function()
	refresh_special_gestures()
end)

refresh_special_gestures()

-- ─── Look & Feel ─────────────────────────────────────────────────────────────

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
		allow_tearing = false,
		layout = "dwindle",
	},
	decoration = {
		rounding = ui.rounding.window,
		rounding_power = (ui.rounding and ui.rounding.power) or 2.0,
		active_opacity = ui.opacity.active,
		inactive_opacity = ui.opacity.inactive,
		dim_inactive = true,
		dim_strength = 0.15,
		dim_special = ui.opacity.dim_special or 0.20,
		shadow = {
			range = 16,
			render_power = 4,
			color = ui.colors.shadow or "rgba(010409ee)",
		},
		blur = {
			enabled = true,
			size = 8,
			passes = 3,
			ignore_opacity = true,
			vibrancy = 0.2,
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
hl.animation({ leaf = "windowsOut", speed = 5, bezier = "myBezier", style = "popin 85%" })
hl.animation({ leaf = "fadeIn", speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", speed = 4, bezier = "default" })
hl.animation({ leaf = "layers", speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", speed = 1.79, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "layersOut", speed = 1.39, bezier = "almostLinear", style = "fade" })
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

hl.layer_rule({
	name = "no-anim-capture",
	match = { namespace = "^(hyprpicker|selection)$" },
	no_anim = true,
})
-- Keybindings cheatsheet: fullscreen blurred overlay (quickshell-keybindings).
hl.layer_rule({
	name = "blur-keybindings-cheatsheet",
	match = { namespace = "^quickshell-keybindings$" },
	blur = true,
	ignore_alpha = 0.2,
})
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})

local function autostart_for(exe)
	local prog = exe:match("^(%S+)")
	if prog ~= nil and prog:find("/", 1, true) ~= nil then
		local f = io.open(prog, "r")
		if f == nil then
			return nil
		end
		f:close()
	end
	return exe
end

for _, app in pairs(programs.special) do
	local ws = "special:" .. app.ws
	hl.workspace_rule({
		workspace = ws,
		on_created_empty = autostart_for(app.exe),
		gaps_out = 48,
	})
	if app.title then
		hl.window_rule({ match = { class = app.class, title = app.title }, workspace = ws })
	else
		hl.window_rule({ match = { class = app.class }, workspace = ws })
	end
end

hl.window_rule({
	name = "picture-in-picture",
	match = { title = "^(Picture-in-Picture)$" },
	float = true,
	pin = true,
	idle_inhibit = "always",
})

hl.window_rule({
	name = "idle-inhibit-fullscreen",
	match = { class = ".*" },
	idle_inhibit = "fullscreen",
})

hl.window_rule({
	match = {
		class = "^(org.gnome.*|com.saivert.pwvucontrol|pavucontrol|nm-connection-editor|blueman-manager|xdg-desktop-portal-gtk|file-roller)$",
	},
	float = true,
	center = true,
})

hl.window_rule({
	name = "ghostty-focus-opacity",
	match = { class = "^(com.mitchellh.ghostty|yazi|btop|jolt)$" },
	opacity = "1.0 0.97",
})

-- ─── Keybindings ────────────────────────────────────────────────────────────────

local function b(keys, desc, dispatcher, opts)
	opts = opts or {}
	opts.description = desc
	-- Pin the default: toggles must not flicker on key hold (SUPER+A held
	-- = panel open/close strobe). Repeating actions (resize, volume,
	-- brightness) opt in explicitly with repeating = true.
	if opts.repeating == nil then
		opts.repeating = false
	end
	hl.bind(keys, dispatcher, opts)
end

-- ─── Navigation ─────────────────────────────────────────────────────────

b("SUPER + Q", "Close window", hl.dsp.window.close())
b("SUPER + F", "Toggle fullscreen", hl.dsp.window.fullscreen())
b("SUPER + T", "Toggle window split", hl.dsp.layout("togglesplit"))

local directions = { H = "left", L = "right", K = "up", J = "down" }
local step = 25

for key, dir in pairs(directions) do
	b("SUPER + " .. key, "Focus " .. dir, hl.dsp.focus({ direction = dir }))
	b("SUPER + SHIFT + " .. key, "Swap window " .. dir, hl.dsp.window.swap({ direction = dir }))

	b(
		"SUPER + CTRL + " .. key,
		"Resize window " .. dir,
		hl.dsp.window.resize({
			x = (dir == "left" and -step) or (dir == "right" and step) or 0,
			y = (dir == "up" and -step) or (dir == "down" and step) or 0,
			relative = true,
		}),
		{ repeating = true }
	)
end

for i = 1, 9 do
	b("SUPER + " .. i, "Switch to workspace " .. i, hl.dsp.focus({ workspace = i }))
	b(
		"SUPER + SHIFT + " .. i,
		"Move window to workspace " .. i,
		hl.dsp.window.move({ workspace = i })
	)
end

local cmds = {
	-- ─── Essential ──────────────────────────────────────────────────────────────

	["SUPER + RETURN"] = { programs.terminal, "Terminal" },
	["SUPER + B"] = { programs.browser, "Browser" },

	--  ─── Quick menus ────────────────────────────────────────────

	["SUPER + space"] = { programs.launcher, "Launcher" },
	["SUPER + A"] = { "qs ipc call quicksettings toggle", "Quick actions" },
	["SUPER + N"] = { "qs ipc call notifications toggle", "Toggle notification center" },
	["SUPER + comma"] = { "qs ipc call notifications dismissLatest", "Close latest notification" },
	["SUPER + SHIFT + comma"] = {
		"qs ipc call notifications invokeDefault",
		"Activate latest notification",
	},
	["SUPER + W"] = { "qs ipc call weather toggle", "Weather" },
	["SUPER + E"] = { "qs ipc call shell toggle launcher emoji", "Emoji picker" },
	["SUPER + C"] = { "qs ipc call shell toggle clipboard ''", "Clipboard history" },
	["SUPER + escape"] = { "hyprlock", "Lock system" },
	["SUPER + slash"] = { "qs ipc call shell toggle keybindings ''", "Keybindings" },

	-- ─── Capture ─────────────────────────────────────────────────────────

	["SUPER + D"] = { "~/.local/bin/dictation", "Dictation" },
	["SUPER + P"] = { "~/.local/bin/wallpaper next", "Next wallpaper" },
	["print"] = { "~/.local/bin/screenshot region", "Screenshot (region)" },
	["SHIFT + print"] = { "~/.local/bin/screenshot fullscreen", "Screenshot (full)" },
}

for bind, entry in pairs(cmds) do
	b(bind, entry[2], hl.dsp.exec_cmd(entry[1]), { repeating = false })
end

local special_apps = {
	["SUPER + SHIFT + A"] = { "gemini", "AI (Gemini)" },
	["SUPER + SHIFT + B"] = { "btop", "Activity Monitor" },
	["SUPER + SHIFT + C"] = { "calendar", "Calendar" },
	["SUPER + SHIFT + E"] = { "mail", "Mail" },
	["SUPER + SHIFT + F"] = { "yazi", "File manager (yazi)" },
	["SUPER + SHIFT + S"] = { "spotify", "Spotify" },
	["SUPER + SHIFT + T"] = { "tasks", "Tasks" },
	["SUPER + SHIFT + W"] = { "whatsapp", "WhatsApp" },
}

for bind, entry in pairs(special_apps) do
	b(
		bind,
		entry[2],
		hl.dsp.workspace.toggle_special(programs.special[entry[1]].ws),
		{ repeating = false }
	)
end

local media = {
	{ "XF86AudioRaiseVolume", "~/.local/bin/volume output raise", true, "Volume up" },
	{
		"XF86AudioLowerVolume",
		"~/.local/bin/volume output lower",
		true,
		"Volume down",
	},
	{ "XF86AudioMute", "~/.local/bin/volume output mute-toggle", nil, "Volume mute" },
	{
		"XF86AudioMicMute",
		"~/.local/bin/volume input mute-toggle",
		nil,
		"Microphone mute",
	},
	{ "XF86MonBrightnessUp", "~/.local/bin/brightness up", true, "Brightness up" },
	{ "XF86MonBrightnessDown", "~/.local/bin/brightness down", true, "Brightness down" },
	{ "XF86TouchpadToggle", "~/.local/bin/touchpad toggle", nil, "Toggle touchpad" },
	{ "XF86TouchpadOn", "~/.local/bin/touchpad on", nil, "Touchpad on" },
	{ "XF86TouchpadOff", "~/.local/bin/touchpad off", nil, "Touchpad off" },
	{ "XF86AudioNext", "playerctl next", nil, "Next track" },
	{ "XF86AudioPause", "playerctl play-pause", nil, "Pause track" },
	{ "XF86AudioPlay", "playerctl play-pause", nil, "Play track" },
	{ "XF86AudioPrev", "playerctl previous", nil, "Previous track" },
}

for _, m in ipairs(media) do
	b(m[1], m[4], hl.dsp.exec_cmd(m[2]), { locked = true, repeating = m[3] })
end

-- ─── Mouse Drag / Resize ─────────────────────────────────────────────────────

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window" })
hl.bind(
	"SUPER + mouse:273",
	hl.dsp.window.resize(),
	{ mouse = true, description = "Resize window" }
)

-- ─── Power Shortcuts (locked = true) ─────────────────────────────────────────
-- non_consuming: bare F1-F3 must still reach apps (F1 help, F3 find).
-- The pidof hyprlock guard makes them no-ops on an unlocked desktop anyway.

b(
	"F1",
	"Power off",
	hl.dsp.exec_cmd("pidof hyprlock >/dev/null && hyprshutdown --post-cmd 'systemctl poweroff'"),
	{ locked = true, non_consuming = true }
)
b(
	"F2",
	"Reboot",
	hl.dsp.exec_cmd("pidof hyprlock >/dev/null && hyprshutdown --post-cmd 'systemctl reboot'"),
	{ locked = true, non_consuming = true }
)
b(
	"F3",
	"Suspend",
	hl.dsp.exec_cmd("pidof hyprlock >/dev/null && systemctl suspend"),
	{ locked = true, non_consuming = true }
)
