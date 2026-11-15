pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// What the settings list can change: the screens (displays.lua), audio, the look (apply-ui),
// the shell's own (Prefs), hypridle's times (idle.conf) and Hyprland's options (settings.lua);
// kind is bool, int, float, enum, text or color.
Singleton {
	id: root

	property var hyprOptions: []
	property var uiValues: []
	property var uiChoices: ({})
	// Hyprland's options changed here, by name, each with its value as Lua:
	// what settings.lua holds, a line edited by hand included.
	property var saved: ({})
	// What Hyprland said to the last change it refused, until the next one.
	property string lastError: ""
	readonly property bool loaded: hyprOptions.length > 0

	readonly property string savedPath: Quickshell.env("HOME") + "/.config/hypr/settings.lua"

	// The screens as Hyprland reports them; the mode and scale chosen here, by output.
	property var monitors: []
	property var savedDisplays: ({})

	// Left out: what ui.toml decides (look.lua), changed there instead, Xwayland, which
	// xwayland-satellite stands in for, what workspaces.lua keeps setting, debug:*, and the
	// VRR each screen has in Displays.
	readonly property var notHere: [
		"general:gaps_in", "general:gaps_out", "general:border_size",
		"general:col.active_border", "general:col.inactive_border",
		"decoration:rounding", "decoration:rounding_power",
		"decoration:active_opacity", "decoration:inactive_opacity", "decoration:dim_special",
		"decoration:shadow:color", "xwayland:enabled", "gestures:workspace_swipe_use_r", "misc:vrr"
	]

	// The pages of the first list, their headings in order. What has no place of its own
	// (curated, uiMeta) is in Advanced, by Hyprland's section.
	readonly property var pages: [
		{ key: "displays", label: "Displays", icon: "monitor", keywords: "monitors screens arrangement" },
		{ key: "sound", label: "Sound", icon: "volume-2" },
		{ key: "appearance", label: "Appearance", icon: "droplet", keywords: "theme look colors wallpaper", subs: ["Wallpaper", "Colors", "Windows", "Effects", "Text", "Pointer", "Apps"] },
		{ key: "desktop", label: "Desktop", icon: "layout-grid", keywords: "bar clock", subs: ["Top bar", "Clock", "Weather", "Night light", "Focus", "Launcher"] },
		{ key: "windows", label: "Windows", icon: "app-window" },
		{ key: "keyboard", label: "Keyboard", icon: "keyboard", subs: ["", "Typing"] },
		{ key: "mouse", label: "Mouse & touchpad", icon: "mouse", subs: ["Mouse", "Touchpad", "Pointer"] },
		{ key: "idle", label: "Idle & sleep", icon: "power" },
		{ key: "advanced", label: "Advanced", icon: "code", keywords: "hyprland options" }
	]

	function page(key: string): var {
		return pages.find(p => p.key === key);
	}

	// A page's settings in its order: by heading, then as listed.
	function pageEntries(key: string): var {
		var subs = page(key)?.subs ?? [];
		var rank = e => {
			var i = subs.indexOf(e.sub);
			return i === -1 ? subs.length : i;
		};
		return entries.filter(e => e.section === key).map((e, i) => ({ e: e, i: i }))
			.sort((a, b) => rank(a.e) - rank(b.e) || a.i - b.i).map(x => x.e);
	}

	// Hyprland's options with a place and a name of their own, in their page's order.
	readonly property var curated: ({
		"general:layout": { section: "windows", label: "Layout", icon: "layout-grid", desc: "How new windows share the screen",
			choices: [["dwindle", "Split in halves"], ["master", "One large, the rest stacked"], ["scrolling", "Side by side, scrolling"], ["monocle", "One at a time"]] },
		"input:follow_mouse": { section: "windows", label: "Focus follows the mouse", icon: "mouse-pointer-2", desc: "The window under the pointer takes the keyboard",
			choices: [[1, "On"], [0, "Off: a click focuses"]] },
		"general:resize_on_border": { section: "windows", label: "Resize from the edges", icon: "maximize-2", desc: "Drag a window's border, or the gap beside it" },
		"misc:focus_on_activate": { section: "windows", label: "Bring forward what asks for it", icon: "app-window", desc: "An app that asks to be seen (a link opened in the browser) comes to the front" },
		"decoration:dim_inactive": { section: "appearance", sub: "Windows", label: "Dim inactive windows", icon: "contrast", desc: "All but the focused window a little darker" },
		"decoration:dim_strength": { section: "appearance", sub: "Windows", label: "How much they dim", icon: "contrast", desc: "Focus dims them more while it is on" },
		"decoration:shadow:enabled": { section: "appearance", sub: "Effects", label: "Window shadows", icon: "square" },
		"decoration:blur:enabled": { section: "appearance", sub: "Effects", label: "Blur", icon: "sparkles", desc: "Frosted glass behind the panels and see-through windows" },
		"animations:enabled": { section: "appearance", sub: "Effects", label: "Animations", icon: "activity", desc: "Windows and workspaces move instead of jumping" },
		"input:kb_layout": { section: "keyboard", label: "Layout", icon: "languages", desc: "What the keys type" },
		"input:kb_variant": { section: "keyboard", label: "Layout variant", icon: "languages", desc: "A variant of the layout as XKB names it (intl, dvorak); empty for none" },
		"input:repeat_delay": { section: "keyboard", sub: "Typing", label: "Repeat after", icon: "clock", desc: "How long a key is held before it repeats, in milliseconds" },
		"input:repeat_rate": { section: "keyboard", sub: "Typing", label: "Repeat speed", icon: "repeat", desc: "Repeats a second while a key is held" },
		"input:numlock_by_default": { section: "keyboard", sub: "Typing", label: "Num Lock on at start", icon: "keyboard" },
		"input:sensitivity": { section: "mouse", sub: "Mouse", label: "Pointer speed", icon: "gauge", desc: "Slower below 0, faster above; the touchpad's too" },
		"input:accel_profile": { section: "mouse", sub: "Mouse", label: "Acceleration", icon: "mouse-pointer-2",
			choices: [["", "Default"], ["adaptive", "Faster as it moves faster"], ["flat", "The same at any speed"]] },
		"input:natural_scroll": { section: "mouse", sub: "Mouse", label: "Natural scrolling", icon: "arrow-down-up", desc: "The page moves with the wheel, as on a phone" },
		"input:scroll_factor": { section: "mouse", sub: "Mouse", label: "Scroll speed", icon: "mouse" },
		"input:left_handed": { section: "mouse", sub: "Mouse", label: "Left-handed", icon: "mouse", desc: "The buttons swapped" },
		"input:touchpad:natural_scroll": { section: "mouse", sub: "Touchpad", label: "Natural scrolling", icon: "arrow-down-up", desc: "The page moves with the fingers, as on a phone" },
		"input:touchpad:tap-to-click": { section: "mouse", sub: "Touchpad", label: "Tap to click", icon: "hand", desc: "One finger clicks, two right-click, three middle-click" },
		"input:touchpad:tap-and-drag": { section: "mouse", sub: "Touchpad", label: "Tap and drag", icon: "hand", desc: "A tap, then hold and move, drags" },
		"input:touchpad:disable_while_typing": { section: "mouse", sub: "Touchpad", label: "Off while typing", icon: "keyboard" },
		"input:touchpad:clickfinger_behavior": { section: "mouse", sub: "Touchpad", label: "Two fingers to right-click", icon: "hand", desc: "A press with two fingers right-clicks, with three middle-clicks, instead of the pad's corners" },
		"input:touchpad:scroll_factor": { section: "mouse", sub: "Touchpad", label: "Scroll speed", icon: "gauge" },
		"cursor:hide_on_key_press": { section: "mouse", sub: "Pointer", label: "Hide while typing", icon: "mouse-pointer-2", desc: "Back as the mouse moves" },
		"cursor:inactive_timeout": { section: "mouse", sub: "Pointer", label: "Hide when still", icon: "clock", desc: "Seconds without a move before it hides; 0 never" }
	})

	readonly property var hyprIcons: ({
		general: "layout-grid", decoration: "sparkles", animations: "activity", input: "keyboard",
		gestures: "hand", group: "layout-grid", misc: "code", binds: "keyboard", cursor: "mouse",
		render: "eye", dwindle: "layout-grid", master: "layout-grid", scrolling: "layout-grid"
	})

	// ui.toml's keys, by name: where they show and how; the ones with no `section` are in Advanced.
	readonly property var uiMeta: ({
		"colors.accent_blue": { section: "appearance", sub: "Colors", label: "Accent", icon: "palette", desc: "What is on or picked, and one end of the windows' border", presets: true },
		"colors.accent_purple": { section: "appearance", sub: "Colors", label: "Second accent", icon: "palette", desc: "The other end of the windows' border", presets: true },
		"rounding.window": { section: "appearance", sub: "Windows", label: "Corner rounding", icon: "rounded-corner", min: 0, max: 24, desc: "How round the corners of windows and panels are, in pixels" },
		"border.size": { section: "appearance", sub: "Windows", label: "Border width", icon: "square", min: 0, max: 8, desc: "The coloured edge of the focused window, in pixels" },
		"spacing.gaps_in": { section: "appearance", sub: "Windows", label: "Gaps between windows", icon: "move", min: 0, max: 40 },
		"spacing.gaps_out": { section: "appearance", sub: "Windows", label: "Gaps at the screen's edges", icon: "move", min: 0, max: 60 },
		"opacity.inactive": { section: "appearance", sub: "Windows", label: "Inactive window opacity", icon: "contrast", min: 0.5, max: 1, step: 0.05 },
		"opacity.dim_special": { section: "appearance", sub: "Windows", label: "Dim behind special workspaces", icon: "contrast", min: 0, max: 1, step: 0.05, desc: "How dark the desktop gets behind an app's special workspace and the panels" },
		"font.family": { section: "appearance", sub: "Text", label: "Shell font", icon: "type", desc: "The bar, the panels and the lock screen" },
		"font.mono": { section: "appearance", sub: "Text", label: "Monospace font", icon: "type", desc: "Terminals and numbers on the bar" },
		"font.ui": { section: "appearance", sub: "Text", label: "App font", icon: "type", desc: "GTK and Qt apps: the family and its size, as \"Adwaita Sans 12\"" },
		"theme.cursor": { section: "appearance", sub: "Pointer", label: "Cursor theme", icon: "mouse-pointer-2" },
		"font.size_cursor": { section: "appearance", sub: "Pointer", label: "Cursor size", icon: "mouse-pointer-2", sizes: [16, 20, 24, 32, 40, 48, 64] },
		"theme.icon": { section: "appearance", sub: "Apps", label: "Icon theme", icon: "palette" },
		"theme.gtk": { section: "appearance", sub: "Apps", label: "App theme", icon: "app-window", desc: "How GTK apps look" },
		"rounding.power": { sub: "Windows", label: "Corner shape", min: 1, max: 10, step: 0.5, desc: "2 is a circle's arc, higher is squarer, as on a phone" },
		"opacity.active": { sub: "Windows", label: "Active window opacity", min: 0.5, max: 1, step: 0.05 },
		"lock.brightness": { sub: "Lock screen", label: "Background brightness", min: 0, max: 1, step: 0.05, desc: "The blurred desktop behind the clock" },
		"lock.vibrancy": { sub: "Lock screen", label: "Background vibrancy", min: 0, max: 1, step: 0.05 },
		"colors.bg_main": { sub: "Theme colors", label: "Background" },
		"colors.bg_card": { sub: "Theme colors", label: "Panels" },
		"colors.bg_hover": { sub: "Theme colors", label: "Hover" },
		"colors.border": { sub: "Theme colors", label: "Borders" },
		"colors.accent_green": { sub: "Theme colors", label: "Success", desc: "Charging, a running app, a result" },
		"colors.warning": { sub: "Theme colors", label: "Warning", desc: "Focus, the night light, low battery" },
		"colors.critical": { sub: "Theme colors", label: "Error" },
		"colors.text_main": { sub: "Theme colors", label: "Text" },
		"colors.text_dim": { sub: "Theme colors", label: "Secondary text" },
		"colors.text_muted": { sub: "Theme colors", label: "Muted text" },
		"colors.shadow": { sub: "Theme colors", label: "Shadow" }
	})

	// GitHub's palette, for the accents.
	readonly property var accentPresets: [["#58a6ff", "Blue"], ["#bc8cff", "Purple"], ["#3fb950", "Green"], ["#39c5cf", "Teal"],
		["#f778ba", "Pink"], ["#db6d28", "Orange"], ["#d29922", "Yellow"], ["#f85149", "Red"]]

	// Asked at every open; ui.toml again after each change (apply-ui, the shell follows ui.json).
	function refresh(): void {
		describe.running = true;
		monitorsQuery.running = true;
		uiDump.running = true;
		wallpaperList.running = true;
	}

	Component.onCompleted: refresh()

	// "col.inactive_border" -> "Color inactive border", "kb_layout" -> "Keyboard layout"
	function humanize(text: string): string {
		var t = text.replace(/^col\./, "color ").replace(/^kb_/, "keyboard ").replace(/[._]/g, " ")
			.replace(/\b(vrr|vfr|dpms|hdr)\b/g, w => w.toUpperCase());
		return t.charAt(0).toUpperCase() + t.slice(1);
	}

	readonly property var uiEntries: uiValues.map(v => {
		var name = v.section + "." + v.key;
		var meta = uiMeta[name] ?? { sub: humanize(v.section), label: humanize(v.key) };
		var section = meta.section ?? "advanced";
		var choices = uiChoices[name] ? uiChoices[name].map(c => ({ label: c, value: c }))
			: meta.sizes ? meta.sizes.concat(meta.sizes.includes(v.value) ? [] : [v.value]).sort((a, b) => a - b).map(n => ({ label: n + " px", value: n }))
			: meta.presets ? accentPresets.concat(accentPresets.some(p => p[0] === v.value) ? [] : [[v.value, "Custom"]]).map(p => ({ label: p[1], value: p[0], swatch: p[0] }))
			: null;
		return {
			id: "ui:" + name,
			source: "ui",
			name: name,
			group: page(section).label + " › " + meta.sub,
			section: section,
			sub: meta.sub,
			label: meta.label,
			desc: meta.desc ?? "",
			kind: choices ? "enum" : v.kind === "str" ? "text" : v.kind,
			stepless: choices !== null && !meta.sizes,
			value: v.value,
			before: v.before,
			min: meta.min ?? null,
			max: meta.max ?? null,
			step: meta.step ?? 1,
			choices: choices,
			// "f0883e" or "#f0883e" as a colour of one's own.
			custom: meta.presets ? t => /^#?[0-9a-f]{6}$/i.test(t.trim()) ? "#" + t.trim().replace("#", "").toLowerCase() : undefined : null,
			customLabel: v => "Custom " + v,
			customHint: meta.presets ? "or type one: #f0883e" : "",
			presets: !!meta.presets,
			icon: meta.icon ?? (meta.sub === "Theme colors" ? "droplet" : meta.sub === "Lock screen" ? "lock" : "app-window")
		};
	})

	readonly property var hyprEntries: hyprOptions.filter(o => !notHere.includes(o.name) && !o.name.startsWith("debug:") && !Array.isArray(o.default)).map((o, order) => {
		var parts = o.name.split(":");
		var last = parts.pop();
		var cur = curated[o.name];
		var section = cur?.section ?? "advanced";
		// Advanced is in Hyprland's sections: "Input › Touchpad".
		var sub = cur ? (cur.sub ?? "") : parts.map(humanize).join(" › ");
		var number = typeof o.default === "number";
		// Hyprland's empty string is "[[EMPTY]]".
		var current = o.current === "[[EMPTY]]" ? "" : o.current;
		var choices = cur?.choices ? cur.choices.concat(cur.choices.some(c => c[0] === current) ? [] : [[current, String(current)]]).map(c => ({ label: c[1], value: c[0] }))
			: number && Array.isArray(o.map) && o.map.length > 0
			? o.map.map(m => ({ label: Object.keys(m)[0], value: m[Object.keys(m)[0]] })).sort((a, b) => a.value - b.value)
			: null;
		// A fraction somewhere, or a range no wider than one (an opacity).
		var float = number && ([o.default, o.current, o.min, o.max].some(n => typeof n === "number" && !Number.isInteger(n))
			|| (typeof o.min === "number" && typeof o.max === "number" && o.max - o.min <= 1));
		// The layout by its name, from XKB's list.
		if (o.name === "input:kb_layout" && root.layouts.length > 0)
			choices = (root.layouts.some(l => l.value === o.current) ? [] : [{ label: String(o.current), value: o.current }]).concat(root.layouts);
		var kind = typeof o.default === "boolean" ? "bool"
			: choices ? "enum"
			: number ? (float ? "float" : "int")
			: /^col\.|color/.test(last) ? "color" : "text";
		return {
			id: "hyprland:" + o.name,
			source: "hyprland",
			name: o.name,
			group: page(section).label + (sub !== "" ? " › " + sub : ""),
			section: section,
			sub: sub,
			order: cur ? Object.keys(curated).indexOf(o.name) : 1000 + order,
			stepless: o.name === "input:kb_layout",
			label: cur?.label ?? humanize(last),
			desc: cur?.desc ?? (o.description ? o.description.charAt(0).toUpperCase() + o.description.slice(1) : ""),
			kind: kind,
			value: current,
			defaultValue: o.default,
			min: typeof o.min === "number" ? o.min : null,
			max: typeof o.max === "number" ? o.max : null,
			step: float ? (o.max - o.min > 10 ? 0.5 : 0.05) : 1,
			choices: choices,
			icon: cur?.icon ?? hyprIcons[parts[0]] ?? "code"
		};
	}).sort((a, b) => a.order - b.order)

	// Known by description where there is one: connector names change per plug and boot.
	function displayOutput(m: var): string {
		return m.description ? "desc:" + m.description : m.name;
	}

	// Scales Hyprland takes without a warning: whole logical pixels, in 1/120 steps.
	function scales(m: var): var {
		var out = [];
		for (var lw = Math.ceil(m.width / 3); lw <= m.width; lw++) {
			if ((m.height * lw) % m.width === 0 && (120 * m.width) % lw === 0)
				out.push(m.width / lw);
		}
		return out.reverse();
	}

	function currentMode(m: var): string {
		return m.width + "x" + m.height + "@" + m.refreshRate.toFixed(2);
	}

	// A laptop's own panel.
	function builtIn(m: var): bool {
		return /^(eDP|LVDS|DSI)/.test(m.name);
	}

	// A screen as people call it: the laptop's own, else its maker and model.
	function displayName(m: var): string {
		if (builtIn(m))
			return "Built-in display";
		var named = [m.make, m.model].filter(t => t && t !== "Unknown").join(" ").trim();
		return named || m.description || m.name;
	}

	readonly property var displayEntries: {
		var brightness = m => Brightness.percent < 0 || !builtIn(m) ? [] : [{
			id: "display:brightness",
			source: "display",
			keywords: "monitors screens backlight",
			name: "Brightness",
			group: "Displays › " + displayName(m),
			section: "displays",
			sub: displayName(m),
			label: "Brightness",
			desc: "The built-in display's backlight",
			kind: "int",
			value: Brightness.percent,
			min: 0,
			max: 100,
			step: 5,
			icon: "sun",
			apply: v => Brightness.setPercent(v)
		}];
		// The backlight with its panel off (lid closed) last, under the panel's name.
		return root.monitors.reduce((list, m) => {
			var output = displayOutput(m);
			var modes = (m.availableModes ?? []).map(s => s.replace(/Hz$/, ""));
			if (!modes.includes(currentMode(m)))
				modes.unshift(currentMode(m));
			var common = {
				source: "display",
				keywords: "monitors screens",
				output: output,
				group: "Displays › " + displayName(m),
				section: "displays",
				sub: displayName(m),
				desc: m.name + (m.description ? " · " + m.description : ""),
				kind: "enum",
				stepless: true,
				fields: ["mode", "scale"]
			};
			var saved = root.savedDisplays[output] ?? {};
			return list.concat(brightness(m), [
				Object.assign({}, common, {
					id: "display:" + m.name + ":mode",
					name: m.name + " mode",
					label: "Resolution and refresh",
					value: currentMode(m),
					choices: modes.map(s => ({ label: s.replace("@", " · ").replace(/\.00$/, "") + " Hz", value: s })),
					icon: "monitor",
					apply: v => root.setDisplay(m, { mode: v, scale: root.scales(m).find(s => Math.abs(s - m.scale) < 0.001) ?? m.scale })
				}),
				Object.assign({}, common, {
					id: "display:" + m.name + ":scale",
					name: m.name + " scale",
					label: "Scale",
					value: m.scale,
					choices: root.scales(m).map(v => Math.abs(v - m.scale) < 0.001 ? m.scale : v).concat([m.scale]).filter((v, i, all) => all.indexOf(v) === i).sort((a, b) => a - b).map(v => ({ label: Math.round(v * 100) + "%", value: v })),
					// "130" or "1.3": the nearest one Hyprland takes, else it warns.
					customLabel: v => Math.round(v * 100) + "%",
					customHint: "or type one: 130%",
					custom: t => {
						var n = Number(t.replace("%", "").replace(",", ".").trim());
						if (t.trim() === "" || isNaN(n) || n <= 0)
							return undefined;
						n = n >= 10 ? n / 100 : n;
						return root.scales(m).reduce((best, v) => Math.abs(v - n) < Math.abs(best - n) ? v : best, 1);
					},
					icon: "sliders-horizontal",
					apply: v => root.setDisplay(m, { mode: currentMode(m), scale: root.scales(m).find(s => Math.abs(s - v) < 0.001) ?? v })
				}),
				Object.assign({}, common, {
					id: "display:" + m.name + ":rotation",
					name: m.name + " rotation",
					label: "Rotation",
					keywords: "monitors screens orientation portrait transform",
					value: m.transform,
					choices: (m.transform < 4 ? [] : [{ label: "Flipped", value: m.transform }]).concat([["Normal", 0], ["90°", 1], ["180°", 2], ["270°", 3]].map(([label, v]) => ({ label: label, value: v }))),
					icon: "rotate-cw",
					fields: ["transform"],
					apply: v => root.setDisplay(m, { transform: v })
				}),
				Object.assign({}, common, {
					id: "display:" + m.name + ":vrr",
					name: m.name + " variable refresh rate",
					label: "Variable refresh rate",
					keywords: "monitors screens vrr adaptive sync freesync g-sync",
					// Hyprland reports only whether it is on now.
					value: saved.vrr ?? (m.vrr ? 1 : 0),
					choices: [{ label: "Off", value: 0 }, { label: "On", value: 1 }, { label: "In fullscreen", value: 2 }],
					icon: "activity",
					fields: ["vrr"],
					apply: v => root.setDisplay(m, { vrr: v })
				})
			]);
		}, [{
			id: "display:arrangement",
			source: "display",
			name: "Arrangement",
			group: "Displays",
			section: "displays",
			sub: "",
			label: "Arrangement",
			desc: "Where the screens stand to each other",
			keywords: "monitors screens layout position arrange",
			kind: "arrange",
			fields: ["position"],
			value: root.monitors.filter(m => m.x > -10000).slice().sort((a, b) => a.x - b.x || a.y - b.y).map(m => displayName(m)).join(" · "),
			icon: "layout-grid"
		}]).concat(root.monitors.some(m => builtIn(m)) ? [] : brightness({ name: "eDP" }));
	}

	readonly property var audioEntries: {
		var common = { source: "audio", group: "Sound", section: "sound", desc: "", keywords: "audio" };
		var device = (name, sinks, node, icon) => Object.assign({}, common, {
			id: "audio:" + name, name: name, label: name, sub: "Devices", kind: "enum", stepless: true, icon: icon,
			value: node?.id ?? -1, choices: Audio.devices(sinks), apply: v => Audio.choose(v)
		});
		var level = (name, value, icon, apply) => Object.assign({}, common, {
			id: "audio:" + name, name: name, label: name, sub: "Levels", kind: "int", min: 0, max: 100, step: 2, icon: icon, value: value, apply: apply
		});
		var mute = (name, value, apply) => Object.assign({}, common, {
			id: "audio:" + name, name: name, label: name, sub: "Levels", kind: "bool", icon: "volume-x", value: value, apply: apply
		});
		return [
			device("Output", true, Audio.sink, "speaker"),
			device("Input", false, Audio.source, "mic"),
			level("Output volume", Audio.volume, "volume-2", v => Audio.setVolume(v)),
			mute("Output muted", Audio.muted, () => Audio.toggleMute()),
			level("Input volume", Audio.inputVolume, "mic", v => Audio.setInputVolume(v)),
			mute("Input muted", Audio.inputMuted, () => Audio.toggleInputMute())
		];
	}

	readonly property var prefEntries: {
		var entry = (key, sub, label, desc, icon, extra) => Object.assign({
			id: "pref:" + key, source: "pref", key: key, name: label, section: "desktop", sub: sub, group: "Desktop › " + sub,
			label: label, desc: desc, kind: "bool", value: Prefs.values[key], icon: icon, apply: v => Prefs.set(key, v)
		}, extra ?? {});
		return [
			entry("batteryPercent", "Top bar", "Battery percentage", "Beside the battery, not only on hover", "battery-medium"),
			entry("weather", "Top bar", "Weather", "The temperature and the sky, a click for the forecast", "cloud-sun"),
			entry("clock24", "Clock", "24-hour time", "Off: 2:05 PM", "calendar", { keywords: "12-hour am pm format" }),
			entry("clockSeconds", "Clock", "Seconds", "In the time on the bar", "calendar"),
			entry("clockWeekday", "Clock", "Day of the week", "Before the date: Wed 4 Nov", "calendar", { keywords: "date" }),
			entry("weatherCity", "Weather", "Location", "A town or a city; empty finds it from the network", "map-pin",
				{ kind: "text", emptyLabel: "Automatic", keywords: "city place forecast" }),
			entry("focusWallpaper", "Focus", "Hide the wallpaper", "While Focus is on: less to look at", "image", { keywords: "dnd do not disturb" }),
			entry("focusDim", "Focus", "Dim other windows", "While Focus is on: the one in use stands out", "contrast", { keywords: "dnd do not disturb" })
		];
	}

	// A time of day as the clock shows it: "20:00" or "8:00 PM".
	function clockLabel(hhmm: string): string {
		var [h, m] = hhmm.split(":").map(Number);
		return Prefs.values.clock24 ? h + ":" + (m < 10 ? "0" : "") + m : Qt.formatTime(new Date(2000, 0, 1, h, m), "h:mm AP");
	}

	function halfHours(from: int, to: int): var {
		var out = [];
		for (var t = from * 2; t <= to * 2; t++)
			out.push(Math.floor(t / 2) + ":" + (t % 2 ? "30" : "00"));
		return out;
	}

	// The night light's schedule (hyprsunset.conf), and the apps hidden from the launcher.
	readonly property var desktopEntries: {
		var night = (key, label, icon, times, value, apply) => ({
			id: "nightlight:" + key, source: "nightlight", key: key, name: label, section: "desktop", sub: "Night light",
			group: "Desktop › Night light", label: label, icon: icon, kind: "enum", value: value, keywords: "night light schedule blue light",
			desc: "On its own each day; the switch in Actions overrides it until the next change",
			choices: times.concat(times.includes(value) ? [] : [value]).map(t => ({ label: clockLabel(t), value: t })),
			apply: apply
		});
		return [
			night("on", "Turns on at", "sunset", halfHours(16, 23), Modes.nightStart, v => Modes.setSchedule(v, Modes.dayStart)),
			night("off", "Turns off at", "sunrise", halfHours(4, 10), Modes.dayStart, v => Modes.setSchedule(Modes.nightStart, v)),
			{
				id: "apps:hidden", source: "apps", name: "Hidden apps", section: "desktop", sub: "Launcher", group: "Desktop › Launcher",
				label: "Hidden apps", icon: "eye-off", kind: "enum", stepless: true, value: "", keywords: "launcher hide show apps",
				valueText: HiddenApps.list.length === 0 ? "None" : HiddenApps.list.length + " hidden",
				desc: "Delete twice on an app in the launcher hides it; pick one here to show it again",
				choices: HiddenApps.list.map(a => ({ label: a.name, value: a.id })),
				apply: v => HiddenApps.unhide(v)
			}
		];
	}

	// The pictures `wallpaper` picks from, by path.
	property var wallpapers: []

	readonly property var wallpaperEntries: wallpapers.length === 0 ? [] : [{
		id: "wallpaper", source: "wallpaper", name: "Wallpaper", section: "appearance", sub: "Wallpaper", group: "Appearance › Wallpaper",
		label: "Wallpaper", icon: "image", kind: "enum", value: Wallpaper.path, keywords: "background picture",
		desc: "Your own go in ~/Pictures/Wallpapers",
		choices: wallpapers.map(p => ({ label: p.split("/").pop().replace(/\.[^.]+$/, "").replace(/[-_]/g, " "), value: p, thumb: "file://" + p })),
		apply: v => Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/wallpaper", "set", v])
	}]

	// hypridle's times, in seconds: hypridle.conf's, and idle.conf's over them.
	property var idleDefaults: ({})
	property var idleSaved: ({})

	function duration(seconds: int): string {
		return seconds % 3600 === 0 ? seconds / 3600 + " h" : Math.round(seconds / 60) + " min";
	}

	readonly property var idleEntries: [
		["lock_after", "Lock the screen after", "lock"],
		["screen_off_after", "Turn the screen off after", "monitor"],
		["sleep_battery_after", "Sleep on battery after", "battery-medium"],
		["sleep_ac_after", "Sleep plugged in after", "power"]
	].filter(([key]) => root.idleDefaults[key] !== undefined).map(([key, label, icon]) => {
		var value = root.idleSaved[key] ?? root.idleDefaults[key];
		var times = [60, 120, 180, 240, 300, 600, 900, 1200, 1800, 2700, 3600, 7200];
		return {
			id: "idle:" + key, source: "idle", key: key, name: label, section: "idle", sub: "", group: "Idle & sleep",
			label: label, desc: "Without input; Keep awake in Actions holds it off", keywords: "timeout suspend lock screen saver",
			kind: "enum", value: value, icon: icon,
			choices: times.concat(times.includes(value) ? [] : [value]).sort((a, b) => a - b).map(t => ({ label: duration(t), value: t })),
			apply: v => root.setIdle(key, v)
		};
	})

	readonly property var entries: displayEntries.concat(audioEntries, wallpaperEntries, uiEntries, prefEntries, desktopEntries, idleEntries, hyprEntries)

	// The value as the list shows it.
	function display(e: var): string {
		if (e.valueText !== undefined)
			return e.valueText;
		if (e.kind === "bool")
			return e.value ? "On" : "Off";
		if (e.kind === "enum")
			return String((e.choices ?? []).find(c => c.value === e.value)?.label ?? e.value);
		if (e.kind === "float")
			return String(Number(Number(e.value).toFixed(3)));
		if (e.kind === "color" && e.source === "hyprland")
			return hyprColorInput(String(e.value));
		// Hyprland's empty string is "[[EMPTY]]".
		return ["", "[[EMPTY]]"].includes(String(e.value)) ? (e.emptyLabel ?? "(none)") : String(e.value);
	}

	// Hyprland reports a colour as AARRGGBB (and an angle, for a gradient);
	// it takes it back as rgba(RRGGBBAA).
	function hyprColorInput(reported: string): string {
		var m = /^([0-9a-f]{2})([0-9a-f]{6})\b/i.exec(reported.trim());
		return m ? "rgba(" + m[2] + m[1] + ")" : reported;
	}

	// The colour of a colour entry, for its swatch, or "".
	function swatch(e: var): string {
		if (e.presets)
			return String(e.value);
		if (e.kind !== "color")
			return "";
		var v = String(e.value).trim();
		var m = /^([0-9a-f]{2})([0-9a-f]{6})\b/i.exec(v);
		if (e.source === "hyprland" && m)
			return "#" + m[1] + m[2];
		var rgba = /^rgba\(([0-9a-f]{6})([0-9a-f]{2})\)$/i.exec(v);
		if (rgba)
			return "#" + rgba[2] + rgba[1];
		return /^#[0-9a-f]{6}$/i.test(v) ? v : "";
	}

	// Set here, over the config: settings.lua, displays.lua, prefs.json or idle.conf; for ui.toml
	// and the night light's times, unlike what they were before (apply-ui keeps that).
	function changed(e: var): bool {
		if (e.source === "display" && e.fields)
			return (e.output ? [root.savedDisplays[e.output] ?? {}] : Object.values(root.savedDisplays)).some(d => e.fields.some(f => d[f] !== undefined));
		if (e.source === "pref")
			return Prefs.changed(e.key);
		if (e.source === "idle")
			return root.idleSaved[e.key] !== undefined;
		if (e.source === "ui")
			return e.before !== undefined && e.before !== null;
		if (e.source === "nightlight")
			return e.value !== (e.key === "on" ? Modes.defaultNightStart : Modes.defaultDayStart);
		return e.source === "hyprland" && root.saved[e.name] !== undefined;
	}

	// The value typed for entry `e`, as the kind it is, or undefined. Switches and
	// choices are not typed.
	function parse(e: var, text: string): var {
		var t = text.trim();
		if (e.kind !== "int" && e.kind !== "float")
			return t;
		var n = Number(t.replace(",", "."));
		if (t === "" || isNaN(n))
			return undefined;
		return clamp(e, e.kind === "int" ? Math.round(n) : n);
	}

	function clamp(e: var, n: real): real {
		if (e.min !== null && e.min !== undefined)
			n = Math.max(e.min, n);
		if (e.max !== null && e.max !== undefined)
			n = Math.min(e.max, n);
		return e.kind === "float" ? Number(n.toFixed(4)) : n;
	}

	// One step of a number, a switch or a list of choices: `delta` -1 or 1.
	function stepped(e: var, delta: int): var {
		if (e.kind === "bool")
			return delta > 0;
		if (e.kind === "enum") {
			var i = e.choices.findIndex(c => c.value === e.value);
			return e.choices[Math.max(0, Math.min(e.choices.length - 1, i + delta))].value;
		}
		if (e.kind === "int" || e.kind === "float")
			return clamp(e, Number(e.value) + delta * e.step);
		return undefined;
	}


	// Out of settings.lua, back to what the config has: Hyprland reads it again.
	function reset(e: var): void {
		if (!changed(e))
			return;
		if (e.source === "display") {
			var outputs = e.output ? [e.output] : Object.keys(root.savedDisplays).filter(k => e.fields.some(f => root.savedDisplays[k][f] !== undefined));
			var kept = Object.assign({}, root.savedDisplays);
			for (const o of outputs) {
				var d = Object.assign({}, kept[o]);
				e.fields.forEach(k => delete d[k]);
				if (Object.keys(d).length === 0)
					delete kept[o];
				else
					kept[o] = d;
			}
			root.savedDisplays = kept;
			displayForget.outputs = outputs;
			writeDisplays();
			return;
		}
		if (e.source === "pref") {
			Prefs.reset(e.key);
			return;
		}
		if (e.source === "idle") {
			setIdle(e.key, root.idleDefaults[e.key]);
			return;
		}
		if (e.source === "ui") {
			uiRun(["--reset=" + e.name]);
			return;
		}
		if (e.source === "nightlight") {
			Modes.setSchedule(e.key === "on" ? Modes.defaultNightStart : Modes.nightStart, e.key === "off" ? Modes.defaultDayStart : Modes.dayStart);
			return;
		}
		var next = Object.assign({}, root.saved);
		delete next[e.name];
		root.saved = next;
		reloadWhenSaved = true;
		write();
	}

	// Everything set here back to the config's.
	function resetAll(): void {
		if (Object.keys(root.saved).length > 0) {
			root.saved = {};
			reloadWhenSaved = true;
			write();
		}
		var outputs = Object.keys(root.savedDisplays);
		if (outputs.length > 0) {
			root.savedDisplays = {};
			displayForget.outputs = outputs;
			writeDisplays();
		}
		Prefs.resetAll();
		if (Object.keys(root.idleSaved).length > 0) {
			root.idleSaved = {};
			writeIdle();
		}
		if (uiEntries.some(e => changed(e)))
			uiRun(["--reset-all"]);
		if (Modes.nightStart !== Modes.defaultNightStart || Modes.dayStart !== Modes.defaultDayStart)
			Modes.setSchedule(Modes.defaultNightStart, Modes.defaultDayStart);
	}

	// apply-ui with `args`, one at a time: a held arrow's last step wins, then ui.toml is read again.
	property var uiPending: null

	function uiRun(args: var): void {
		if (uiApply.running) {
			uiPending = args;
			return;
		}
		uiApply.command = [Quickshell.env("HOME") + "/.local/bin/apply-ui"].concat(args);
		uiApply.running = true;
	}

	Process {
		id: uiApply
		stderr: StdioCollector {
			onStreamFinished: {
				if (this.text.trim() !== "")
					root.lastError = this.text.trim().split("\n").pop();
			}
		}
		onExited: {
			if (root.uiPending) {
				var next = root.uiPending;
				root.uiPending = null;
				root.uiRun(next);
			} else {
				uiDump.running = true;
			}
		}
	}

	// Only a time unlike hypridle.conf's is kept.
	function setIdle(key: string, seconds: int): void {
		var next = Object.assign({}, root.idleSaved);
		if (seconds === root.idleDefaults[key])
			delete next[key];
		else
			next[key] = seconds;
		root.idleSaved = next;
		writeIdle();
	}

	function writeIdle(): void {
		idleFile.setText("# Written by the shell's settings (SUPER + S): hypridle's times in seconds, over\n"
			+ "# hypridle.conf's. A line taken out goes back to it.\n"
			+ Object.keys(root.idleSaved).sort().map(k => "$" + k + " = " + root.idleSaved[k] + "\n").join(""));
	}

	// The file is written off the GUI thread: Hyprland reads it once it is.
	property bool reloadWhenSaved: false

	// Into settings.lua once Hyprland takes it.
	function set(e: var, value: var): void {
		root.lastError = "";
		if (value === undefined || String(value) === String(e.value))
			return;
		if (e.apply) {
			e.apply(value);
		} else if (e.source === "ui") {
			// Shown at once, as Hyprland's are.
			root.uiValues = root.uiValues.map(v => v.section + "." + v.key === e.name ? Object.assign({}, v, { value: value, before: v.before ?? e.value }) : v);
			uiRun(["--set=" + e.name + "=" + String(value)]);
		} else {
			if (e.kind === "color")
				value = hyprColorInput(String(value));
			// Shown at once, so that the next step (a held arrow) goes on
			// from it; Hyprland's answer puts it right.
			root.hyprOptions = root.hyprOptions.map(o => o.name === e.name ? Object.assign({}, o, { current: value }) : o);
			queue.push({ option: e.name, value: value });
			pump();
		}
	}

	// One change at a time, in the order made.
	property var queue: []

	function pump(): void {
		if (apply.running || queue.length === 0)
			return;
		var next = queue.shift();
		apply.option = next.option;
		apply.value = next.value;
		apply.command = ["hyprctl", "dispatch", "function() hl.config(" + luaTree(next.option, luaValue(next.value)) + ") end"];
		apply.running = true;
	}

	function luaValue(v: var): string {
		return typeof v === "boolean" ? String(v) : typeof v === "number" ? String(v) : Hypr.quote(String(v));
	}

	// "decoration:blur:passes" -> { ["decoration"] = { ["blur"] = { ["passes"] = v } } }
	function luaTree(name: string, value: string): string {
		return name.split(/[:.]/).reverse().reduce((inner, part) => "{ [" + Hypr.quote(part) + "] = " + inner + " }", value);
	}

	// The screen's rule as it stands, with `change` ({ mode, scale, position, transform, vrr }) over it.
	function monitorCall(m: var, change: var): string {
		var f = Object.assign({ mode: currentMode(m), position: m.x + "x" + m.y, scale: m.scale, transform: m.transform },
			root.savedDisplays[displayOutput(m)]?.vrr !== undefined ? { vrr: root.savedDisplays[displayOutput(m)].vrr } : {}, change);
		return "hl.monitor({ output = " + Hypr.quote(displayOutput(m)) + ", mode = " + Hypr.quote(f.mode) + ", position = " + Hypr.quote(f.position)
			+ ", scale = " + f.scale + ", transform = " + f.transform + (f.vrr !== undefined ? ", vrr = " + f.vrr : "") + " })";
	}

	// The screen where it is, with `change` over it; kept once Hyprland took it.
	function setDisplay(m: var, change: var): void {
		displayApply.output = displayOutput(m);
		displayApply.change = change;
		displayApply.command = ["hyprctl", "dispatch", "function() " + monitorCall(m, change) + " end"];
		displayApply.running = true;
	}

	// The screens where the arrangement put them, `places` as { output: "XxY" }; kept once
	// Hyprland took them all.
	function arrange(places: var): void {
		var calls = root.monitors.filter(m => places[displayOutput(m)] !== undefined).map(m => monitorCall(m, { position: places[displayOutput(m)] }));
		arrangeApply.places = places;
		arrangeApply.command = ["hyprctl", "dispatch", "function() " + calls.join(" ") + " end"];
		arrangeApply.running = true;
	}

	Process {
		id: arrangeApply
		property var places: ({})

		stdout: StdioCollector {
			id: arrangeOut
		}

		onExited: {
			var said = arrangeOut.text.trim();
			if (said === "ok") {
				var next = Object.assign({}, root.savedDisplays);
				for (const o of Object.keys(places))
					next[o] = Object.assign({}, next[o], { position: places[o] });
				root.savedDisplays = next;
				root.writeDisplays();
			} else {
				root.lastError = said.replace(/^error: .*?:1: /, "");
			}
			monitorsAfter.restart();
		}
	}

	function writeDisplays(): void {
		var lines = Object.keys(root.savedDisplays).sort().map(k => {
			var d = root.savedDisplays[k];
			var fields = [];
			if (d.mode !== undefined)
				fields.push("mode = " + Hypr.quote(d.mode));
			if (d.scale !== undefined)
				fields.push("scale = " + d.scale);
			if (d.position !== undefined)
				fields.push("position = " + Hypr.quote(d.position));
			if (d.transform !== undefined)
				fields.push("transform = " + d.transform);
			if (d.vrr !== undefined)
				fields.push("vrr = " + d.vrr);
			return "\t[" + Hypr.quote(k) + "] = { " + fields.join(", ") + " },";
		});
		displaysFile.setText("-- Written by the shell's settings (SUPER + S): each screen's mode, scale, place, rotation\n"
			+ "-- and VRR (hyprland/monitors.lua). A line taken out goes back to the config's.\n"
			+ "return {\n" + lines.join("\n") + (lines.length > 0 ? "\n" : "") + "}\n");
	}

	function write(): void {
		var lines = Object.keys(root.saved).sort().map(k => "\t[" + Hypr.quote(k) + "] = " + root.saved[k] + ",");
		savedFile.setText("-- Written by the shell's settings (SUPER + S): Hyprland's options changed\n"
			+ "-- there (hyprland/settings.lua). A line taken out goes back to the config's.\n"
			+ "return {\n" + lines.join("\n") + (lines.length > 0 ? "\n" : "") + "}\n");
	}

	// Asked at every open: the same answer leaves the entries alone, or the list's rows
	// would all be made again as the panel opens.
	Process {
		id: describe
		property var answer
		command: ["hyprctl", "descriptions", "-j"]
		stdout: StdioCollector {
			onStreamFinished: {
				if (this.text === describe.answer)
					return;
				try {
					root.hyprOptions = JSON.parse(this.text);
					describe.answer = this.text;
				} catch (e) {
					root.lastError = "hyprctl descriptions: " + e;
				}
			}
		}
	}

	Process {
		id: uiDump
		property var answer
		command: [Quickshell.env("HOME") + "/.local/bin/apply-ui", "--dump"]
		stdout: StdioCollector {
			onStreamFinished: {
				if (this.text === uiDump.answer)
					return;
				try {
					var d = JSON.parse(this.text);
					root.uiValues = d.values;
					root.uiChoices = d.choices;
					uiDump.answer = this.text;
				} catch (e) {
					root.lastError = "apply-ui --dump: " + e;
				}
			}
		}
	}

	Process {
		id: wallpaperList
		command: [Quickshell.env("HOME") + "/.local/bin/wallpaper", "list"]
		stdout: StdioCollector {
			onStreamFinished: root.wallpapers = this.text.split("\n").filter(l => l !== "")
		}
	}

	Process {
		id: monitorsQuery
		command: ["hyprctl", "monitors", "-j"]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					root.monitors = JSON.parse(this.text).filter(m => m.name !== "FALLBACK");
				} catch (e) {
					root.lastError = "hyprctl monitors: " + e;
				}
			}
		}
	}

	Process {
		id: displayApply

		property string output: ""
		property var change: ({})

		stdout: StdioCollector {
			id: displayOut
		}

		onExited: {
			var said = displayOut.text.trim();
			if (said === "ok") {
				var next = Object.assign({}, root.savedDisplays);
				next[output] = Object.assign({}, next[output], change);
				root.savedDisplays = next;
				root.writeDisplays();
			} else {
				root.lastError = said.replace(/^error: .*?:1: /, "");
			}
			monitorsAfter.restart();
		}
	}

	// Once displays.lua no longer has it.
	Process {
		id: displayForget
		property var outputs: []
		command: ["hyprctl", "dispatch", "function() local m = require(\"hyprland.monitors\") " + outputs.map(o => "m.forget(" + Hypr.quote(o) + ")").join(" ") + " end"]
		onExited: {
			outputs = [];
			monitorsAfter.restart();
		}
	}

	// Hyprland applies a rule on its next refresh.
	Timer {
		id: monitorsAfter
		interval: 300
		onTriggered: monitorsQuery.running = true
	}

	FileView {
		id: displaysFile
		path: Quickshell.env("HOME") + "/.config/hypr/displays.lua"
		blockLoading: true
		printErrors: false
		onSaved: {
			if (displayForget.outputs.length > 0)
				displayForget.running = true;
		}
		onLoaded: {
			var found = {};
			for (const line of this.text().split("\n")) {
				var m = /^\s*\["([^"]+)"\]\s*=\s*\{(.*)\},\s*$/.exec(line);
				if (!m)
					continue;
				var d = {};
				var mode = /mode = "([^"]+)"/.exec(m[2]), scale = /scale = ([0-9.]+)/.exec(m[2]), position = /position = "(-?\d+x-?\d+)"/.exec(m[2]);
				if (mode)
					d.mode = mode[1];
				if (scale)
					d.scale = Number(scale[1]);
				if (position)
					d.position = position[1];
				var transform = /transform = (\d)/.exec(m[2]), vrr = /vrr = (\d)/.exec(m[2]);
				if (transform)
					d.transform = Number(transform[1]);
				if (vrr)
					d.vrr = Number(vrr[1]);
				found[m[1]] = d;
			}
			root.savedDisplays = found;
		}
	}

	// Kept only once Hyprland took it.
	Process {
		id: apply

		property string option: ""
		property var value

		stdout: StdioCollector {
			id: applyOut
		}

		onExited: {
			var said = applyOut.text.trim();
			if (said === "ok") {
				var next = Object.assign({}, root.saved);
				next[apply.option] = root.luaValue(apply.value);
				root.saved = next;
				root.write();
			} else {
				root.lastError = said.replace(/^error: .*?:1: /, "");
			}
			if (root.queue.length > 0)
				Qt.callLater(root.pump);
			else
				describe.running = true;
		}
	}

	// Each line as write() makes it: ["name"] = value,
	FileView {
		id: savedFile
		path: root.savedPath
		blockLoading: true
		printErrors: false
		onSaved: {
			if (root.reloadWhenSaved) {
				root.reloadWhenSaved = false;
				Hypr.reload(() => describe.running = true);
			}
		}
		onLoaded: {
			var found = {};
			for (const line of this.text().split("\n")) {
				var m = /^\s*\["([^"]+)"\]\s*=\s*(.+?),\s*$/.exec(line);
				if (m)
					found[m[1]] = m[2];
			}
			root.saved = found;
		}
	}

	// `$name = seconds` lines: hypridle.conf's first, idle.conf's over them.
	function idleTimes(text: string): var {
		var found = {};
		for (const line of text.split("\n")) {
			var m = /^\$(\w+)\s*=\s*(\d+)\s*$/.exec(line);
			if (m)
				found[m[1]] = Number(m[2]);
		}
		return found;
	}

	FileView {
		path: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"
		blockLoading: true
		printErrors: false
		onLoaded: root.idleDefaults = root.idleTimes(this.text())
	}

	FileView {
		id: idleFile
		path: Quickshell.env("HOME") + "/.config/hypr/idle.conf"
		blockLoading: true
		printErrors: false
		onLoaded: root.idleSaved = root.idleTimes(this.text())
		onSaved: idleRestart.running = true
	}

	// hypridle reads its config once.
	Process {
		id: idleRestart
		command: ["systemctl", "--user", "try-restart", "hypridle.service"]
	}

	// XKB's layouts by name: { label: "Polish", value: "pl" }.
	property var layouts: []

	FileView {
		path: "/usr/share/X11/xkb/rules/base.lst"
		printErrors: false
		onLoaded: {
			var text = this.text();
			var start = text.indexOf("! layout"), end = text.indexOf("!", start + 1);
			root.layouts = text.slice(start, end).split("\n").slice(1).map(l => /^\s+(\S+)\s+(.+)$/.exec(l)).filter(m => m)
				.map(m => ({ label: m[2].trim(), value: m[1] })).sort((a, b) => a.label.localeCompare(b.label));
		}
	}
}
