pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// What the settings list can change: modes, the look (apply-ui) and Hyprland's
// options (kept in ~/.config/hypr/settings.lua); kind is bool, int, float, enum, text or color.
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

	// Left out: what ui.toml decides (look.lua), changed there instead, and
	// Xwayland, which xwayland-satellite stands in for.
	readonly property var notHere: [
		"general:gaps_in", "general:gaps_out", "general:border_size",
		"general:col.active_border", "general:col.inactive_border",
		"decoration:rounding", "decoration:rounding_power",
		"decoration:active_opacity", "decoration:inactive_opacity", "decoration:dim_special",
		"decoration:shadow:color", "xwayland:enabled"
	]

	readonly property var hyprIcons: ({
		general: "layout-grid", decoration: "sparkles", animations: "activity", input: "keyboard",
		gestures: "hand", group: "layout-grid", misc: "code", binds: "keyboard", cursor: "mouse",
		render: "eye", dwindle: "layout-grid", master: "layout-grid", scrolling: "layout-grid"
	})

	function refresh(): void {
		describe.running = true;
		uiDump.running = true;
	}

	// "col.inactive_border" -> "Color inactive border"
	function humanize(text: string): string {
		var t = text.replace(/^col\./, "color ").replace(/[._]/g, " ");
		return t.charAt(0).toUpperCase() + t.slice(1);
	}

	readonly property var modeEntries: Commands.all.filter(c => c.active !== undefined).map(c => ({
		id: "mode:" + c.id,
		source: "mode",
		name: c.id,
		group: "Desktop",
		label: c.name,
		desc: c.desc,
		kind: "bool",
		value: c.active,
		icon: c.icon,
		keywords: c.keywords
	}))

	readonly property var uiEntries: uiValues.map(v => {
		var name = v.section + "." + v.key;
		var choices = uiChoices[name];
		return {
			id: "ui:" + name,
			source: "ui",
			name: name,
			group: "Look · " + humanize(v.section),
			label: humanize(v.key),
			desc: "ui.toml · the whole desktop",
			kind: choices ? "enum" : v.kind === "str" ? "text" : v.kind,
			value: v.value,
			step: v.kind === "float" ? 0.05 : 1,
			choices: choices ? choices.map(c => ({ label: c, value: c })) : null,
			icon: v.section === "colors" ? "droplet" : v.section === "font" ? "text" : "sparkles"
		};
	})

	readonly property var hyprEntries: hyprOptions.filter(o => !notHere.includes(o.name) && !Array.isArray(o.default)).map(o => {
		var parts = o.name.split(":");
		var last = parts.pop();
		var number = typeof o.default === "number";
		var choices = number && Array.isArray(o.map) && o.map.length > 0
			? o.map.map(m => ({ label: Object.keys(m)[0], value: m[Object.keys(m)[0]] })).sort((a, b) => a.value - b.value)
			: null;
		// A fraction somewhere, or a range no wider than one (an opacity).
		var float = number && ([o.default, o.current, o.min, o.max].some(n => typeof n === "number" && !Number.isInteger(n))
			|| (typeof o.min === "number" && typeof o.max === "number" && o.max - o.min <= 1));
		var kind = typeof o.default === "boolean" ? "bool"
			: choices ? "enum"
			: number ? (float ? "float" : "int")
			: /^col\.|color/.test(last) ? "color" : "text";
		return {
			id: "hyprland:" + o.name,
			source: "hyprland",
			name: o.name,
			group: parts.map(humanize).join(" › "),
			label: humanize(last),
			desc: o.description,
			kind: kind,
			value: o.current,
			defaultValue: o.default,
			min: typeof o.min === "number" ? o.min : null,
			max: typeof o.max === "number" ? o.max : null,
			step: float ? (o.max - o.min > 10 ? 0.5 : 0.05) : 1,
			choices: choices,
			icon: hyprIcons[parts[0]] ?? "code"
		};
	})

	readonly property var entries: modeEntries.concat(uiEntries, hyprEntries)

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
		return String(e.value) === "" ? "(none)" : String(e.value);
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

	// Set here, so in settings.lua.
	function changed(e: var): bool {
		return e.source === "hyprland" && root.saved[e.name] !== undefined;
	}

	// The value typed for entry `e`, as the kind it is, or undefined.
	function parse(e: var, text: string): var {
		var t = text.trim();
		if (e.kind === "int" || e.kind === "float") {
			var n = Number(t.replace(",", "."));
			if (t === "" || isNaN(n))
				return undefined;
			return clamp(e, e.kind === "int" ? Math.round(n) : n);
		}
		if (e.kind === "bool")
			return ["on", "true", "1", "yes"].includes(t.toLowerCase());
		if (e.kind === "enum")
			return e.choices.find(c => String(c.label).toLowerCase() === t.toLowerCase())?.value;
		return t;
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


	// Out of settings.lua, back to what the config has: Hyprland reads it
	// again (and power-save puts its own back, as apply-ui has it).
	function reset(e: var): void {
		if (!changed(e))
			return;
		var next = Object.assign({}, root.saved);
		delete next[e.name];
		root.saved = next;
		reloadWhenSaved = true;
		write();
	}

	// The file is written off the GUI thread: Hyprland reads it once it is.
	property bool reloadWhenSaved: false

	// Into settings.lua once Hyprland takes it.
	function set(e: var, value: var): void {
		root.lastError = "";
		if (value === undefined || String(value) === String(e.value))
			return;
		if (e.source === "mode") {
			Commands.run(e.name);
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

	function write(): void {
		var lines = Object.keys(root.saved).sort().map(k => "\t[" + Hypr.quote(k) + "] = " + root.saved[k] + ",");
		savedFile.setText("-- Written by the shell's settings (SUPER + S): Hyprland's options changed\n"
			+ "-- there (hyprland/settings.lua). A line taken out goes back to the config's.\n"
			+ "return {\n" + lines.join("\n") + (lines.length > 0 ? "\n" : "") + "}\n");
	}

	Process {
		id: describe
		command: ["hyprctl", "descriptions", "-j"]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					root.hyprOptions = JSON.parse(this.text);
				} catch (e) {
					root.lastError = "hyprctl descriptions: " + e;
				}
			}
		}
	}

	Process {
		id: uiDump
		command: [Quickshell.env("HOME") + "/.local/bin/apply-ui", "--dump"]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					var d = JSON.parse(this.text);
					root.uiValues = d.values;
					root.uiChoices = d.choices;
				} catch (e) {
					root.lastError = "apply-ui --dump: " + e;
				}
			}
		}
	}

	Process {
		id: reload
		command: ["sh", "-c", "hyprctl reload >/dev/null; \"$HOME/.local/bin/power-save\" --reapply >/dev/null 2>&1"]
		onExited: describe.running = true
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
				reload.running = true;
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
}
