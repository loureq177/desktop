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
	// xwayland-satellite stands in for, what workspaces.lua keeps setting, and debug:*.
	readonly property var notHere: [
		"general:gaps_in", "general:gaps_out", "general:border_size",
		"general:col.active_border", "general:col.inactive_border",
		"decoration:rounding", "decoration:rounding_power",
		"decoration:active_opacity", "decoration:inactive_opacity", "decoration:dim_special",
		"decoration:shadow:color", "xwayland:enabled", "gestures:workspace_swipe_use_r"
	]

	// The pages of the first list. A Hyprland option goes to the first one with a prefix it
	// starts with, else to Advanced; the prefixes' order is the page's.
	readonly property var pages: [
		{ key: "displays", label: "Displays", icon: "monitor" },
		{ key: "sound", label: "Sound", icon: "volume-2" },
		{ key: "appearance", label: "Appearance", icon: "droplet", prefixes: ["decoration:", "animations:"] },
		{ key: "desktop", label: "Desktop", icon: "layout-grid" },
		{ key: "windows", label: "Windows", icon: "app-window", prefixes: ["general:", "layout:", "dwindle:", "master:", "scrolling:", "group:"] },
		{ key: "keyboard", label: "Keyboard", icon: "keyboard", prefixes: ["input:kb_", "input:repeat_", "input:numlock", "input:resolve_binds", "input:virtualkeyboard:", "binds:"] },
		{ key: "mouse", label: "Mouse & touchpad", icon: "mouse", prefixes: ["input:", "gestures:", "cursor:"] },
		{ key: "idle", label: "Idle & sleep", icon: "power" },
		{ key: "advanced", label: "Advanced", icon: "code", prefixes: [""] }
	]

	function page(key: string): var {
		return pages.find(p => p.key === key);
	}

	// { page, rank }: where a Hyprland option goes, and its place there.
	function placeOf(name: string): var {
		for (const p of pages) {
			var i = (p.prefixes ?? []).findIndex(x => name.startsWith(x));
			if (i !== -1)
				return { page: p, rank: i };
		}
	}

	readonly property var hyprIcons: ({
		general: "layout-grid", decoration: "sparkles", animations: "activity", input: "keyboard",
		gestures: "hand", group: "layout-grid", misc: "code", binds: "keyboard", cursor: "mouse",
		render: "eye", dwindle: "layout-grid", master: "layout-grid", scrolling: "layout-grid"
	})

	// ui.toml changes only through apply-ui, which restarts the shell.
	function refresh(): void {
		describe.running = true;
		monitorsQuery.running = true;
		if (uiValues.length === 0)
			uiDump.running = true;
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
		var choices = uiChoices[name];
		return {
			id: "ui:" + name,
			source: "ui",
			name: name,
			group: "Appearance › " + humanize(v.section),
			section: "appearance",
			sub: humanize(v.section),
			label: humanize(v.key),
			desc: "ui.toml · the whole desktop",
			kind: choices ? "enum" : v.kind === "str" ? "text" : v.kind,
			value: v.value,
			choices: choices ? choices.map(c => ({ label: c, value: c })) : null,
			icon: v.section === "colors" ? "droplet" : v.section === "font" ? "text" : "sparkles"
		};
	})

	readonly property var hyprEntries: hyprOptions.filter(o => !notHere.includes(o.name) && !o.name.startsWith("debug:") && !Array.isArray(o.default)).map((o, order) => {
		var parts = o.name.split(":");
		var last = parts.pop();
		var place = placeOf(o.name);
		// The page's first section needs no heading; Advanced is all headings.
		var advanced = place.page.key === "advanced";
		var sub = parts.length > 1 ? parts.slice(1).map(humanize).join(" › ") : place.rank === 0 && !advanced ? "" : humanize(parts[0]);
		var number = typeof o.default === "number";
		var choices = number && Array.isArray(o.map) && o.map.length > 0
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
			group: place.page.label + (sub !== "" ? " › " + sub : ""),
			section: place.page.key,
			sub: sub,
			order: place.rank * 10000 + order,
			stepless: o.name === "input:kb_layout",
			label: humanize(last),
			desc: o.description,
			kind: kind,
			value: o.current,
			defaultValue: o.default,
			min: typeof o.min === "number" ? o.min : null,
			max: typeof o.max === "number" ? o.max : null,
			step: float ? (o.max - o.min > 10 ? 0.5 : 0.05) : 1,
			choices: choices,
			icon: advanced ? hyprIcons[parts[0]] ?? "code" : place.page.icon
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

	readonly property var displayEntries: {
		var brightness = Brightness.percent < 0 ? [] : [{
			id: "display:brightness",
			source: "display",
			keywords: "monitors screens backlight",
			name: "Brightness",
			group: "Displays",
			section: "displays",
			sub: "",
			label: "Brightness",
			desc: "The built-in panel",
			kind: "int",
			value: Brightness.percent,
			min: 0,
			max: 100,
			step: 5,
			icon: "sun",
			apply: v => Brightness.setPercent(v)
		}];
		return root.monitors.reduce((list, m) => {
			var output = displayOutput(m);
			var modes = (m.availableModes ?? []).map(s => s.replace(/Hz$/, ""));
			if (!modes.includes(currentMode(m)))
				modes.unshift(currentMode(m));
			var common = {
				source: "display",
				keywords: "monitors screens",
				output: output,
				group: "Displays › " + (m.description || m.name),
				section: "displays",
				sub: m.description || m.name,
				desc: m.name,
				kind: "enum",
				stepless: true,
				fields: ["mode", "scale"]
			};
			var saved = root.savedDisplays[output] ?? {};
			return list.concat([
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
		}, brightness.concat(root.monitors.filter(m => m.x > -10000).length < 2 ? [] : [{
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
			value: root.monitors.filter(m => m.x > -10000).slice().sort((a, b) => a.x - b.x || a.y - b.y).map(m => m.name).join(" · "),
			icon: "layout-grid"
		}]));
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

	// Panels.qml's shortcuts a hot corner can press.
	readonly property var cornerChoices: [["Apps", "launcher-apps"], ["Open windows", "launcher-windows"], ["Actions", "actions"],
		["Notifications", "notifications"], ["Settings", "launcher-settings"], ["Nothing", ""]].map(([label, v]) => ({ label: label, value: v }))

	readonly property var prefEntries: {
		var entry = (key, sub, label, desc, icon, extra) => Object.assign({
			id: "pref:" + key, source: "pref", key: key, name: label, section: "desktop", sub: sub, group: "Desktop › " + sub,
			label: label, desc: desc, kind: "bool", value: Prefs.values[key], icon: icon, apply: v => Prefs.set(key, v)
		}, extra ?? {});
		return [
			entry("cornerLeft", "Hot corners", "Top-left corner", "What the pointer pushed into the corner opens", "layout-grid", { kind: "enum", choices: cornerChoices }),
			entry("cornerRight", "Hot corners", "Top-right corner", "What the pointer pushed into the corner opens", "layout-grid", { kind: "enum", choices: cornerChoices }),
			entry("batteryPercent", "Top bar", "Battery percentage", "Beside the battery, not only on hover", "battery-medium"),
			entry("weather", "Top bar", "Weather", "The temperature and the sky, a click for the forecast", "cloud-sun"),
			entry("clock24", "Clock", "24-hour time", "Off: 2:05 PM", "calendar", { keywords: "12-hour am pm format" }),
			entry("clockSeconds", "Clock", "Seconds", "In the time on the bar", "calendar"),
			entry("clockWeekday", "Clock", "Day of the week", "Before the date: Wed 4 Nov", "calendar", { keywords: "date" })
		];
	}

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

	readonly property var entries: displayEntries.concat(audioEntries, uiEntries, prefEntries, idleEntries, hyprEntries)

	// The value as the list shows it.
	function display(e: var): string {
		if (e.kind === "bool")
			return e.value ? "On" : "Off";
		if (e.kind === "enum")
			return String((e.choices ?? []).find(c => c.value === e.value)?.label ?? e.value);
		if (e.kind === "float")
			return String(Number(Number(e.value).toFixed(3)));
		if (e.kind === "color" && e.source === "hyprland")
			return hyprColorInput(String(e.value));
		// Hyprland's empty string is "[[EMPTY]]".
		return ["", "[[EMPTY]]"].includes(String(e.value)) ? "(none)" : String(e.value);
	}

	// Hyprland reports a colour as AARRGGBB (and an angle, for a gradient);
	// it takes it back as rgba(RRGGBBAA).
	function hyprColorInput(reported: string): string {
		var m = /^([0-9a-f]{2})([0-9a-f]{6})\b/i.exec(reported.trim());
		return m ? "rgba(" + m[2] + m[1] + ")" : reported;
	}

	// The colour of a colour entry, for its swatch, or "".
	function swatch(e: var): string {
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

	// Set here, over the config: settings.lua, displays.lua, prefs.json or idle.conf.
	function changed(e: var): bool {
		if (e.source === "display" && e.fields)
			return (e.output ? [root.savedDisplays[e.output] ?? {}] : Object.values(root.savedDisplays)).some(d => e.fields.some(f => d[f] !== undefined));
		if (e.source === "pref")
			return Prefs.changed(e.key);
		if (e.source === "idle")
			return root.idleSaved[e.key] !== undefined;
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
			Hypr.exec([Quickshell.env("HOME") + "/.local/bin/apply-ui", "--set=" + e.name + "=" + String(value)]);
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

	// XKB's layouts by name: { label: "Polish (pl)", value: "pl" }.
	property var layouts: []

	FileView {
		path: "/usr/share/X11/xkb/rules/base.lst"
		printErrors: false
		onLoaded: {
			var text = this.text();
			var start = text.indexOf("! layout"), end = text.indexOf("!", start + 1);
			root.layouts = text.slice(start, end).split("\n").slice(1).map(l => /^\s+(\S+)\s+(.+)$/.exec(l)).filter(m => m)
				.map(m => ({ label: m[2].trim() + " (" + m[1] + ")", value: m[1] })).sort((a, b) => a.label.localeCompare(b.label));
		}
	}
}
