pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// Hyprland's binds and the shell's own keys, for the launcher's keys list; what is
// changed there goes into ~/.config/hypr/keys.lua (binds.lua reads it).
Singleton {
	id: root

	// { id, category, action, chord, mask, keys, label, editable, modsOnly, removed }, one
	// line for the binds that share a description and modifiers (SUPER + 1..9); media
	// keys and switches left out. modsOnly: several keys or a mouse button, only the
	// modifiers change. removed: taken off here, back with reset().
	property var entries: []
	property var binds: []
	property bool loaded: false
	// The lines changed here, by description: { mods, key } (key "" for modsOnly),
	// { off } or a new one, { mods, key, run }.
	property var saved: ({})
	property string lastError: ""

	readonly property string savedPath: Quickshell.env("HOME") + "/.config/hypr/keys.lua"

	readonly property var keyNames: ({
		"comma": ",",
		"period": ".",
		"slash": "/",
		"space": "SPACE",
		"return": "RETURN",
		"escape": "ESC",
		"print": "PRINT",
		"left": "←",
		"down": "↓",
		"up": "↑",
		"right": "→",
		"minus": "-",
		"equal": "=",
		"semicolon": ";",
		"apostrophe": "'",
		"bracketleft": "[",
		"bracketright": "]",
		"backslash": "\\",
		"grave": "`",
		"mouse:272": "LEFT DRAG",
		"mouse:273": "RIGHT DRAG",
		"mouse_down": "SCROLL ↓",
		"mouse_up": "SCROLL ↑"
	})

	// The shell's own keys, shown nowhere else (not Esc and J / K, which every panel takes).
	readonly property var shellEntries: [
		{ category: "Mouse", chord: "RIGHT-CLICK BAR ICON", action: "Close a special workspace", special: true },
		{ category: "Gestures", chord: "3 FINGERS ↔", action: "Switch workspace" },
		{ category: "Gestures", chord: "3 FINGERS ↑", action: "Open the last special workspace", special: true },
		{ category: "Gestures", chord: "3 FINGERS ↓", action: "Hide the special workspace", special: true }
	]

	// Hyprland's modifier bits, in the order a chord names them: as shown, as Lua writes them.
	readonly property var modifiers: [
		{ bit: 64, label: "SUPER", lua: "SUPER" },
		{ bit: 4, label: "CTRL", lua: "CTRL" },
		{ bit: 8, label: "ALT", lua: "ALT" },
		{ bit: 128, label: "ALTGR", lua: "MOD5" },
		{ bit: 1, label: "SHIFT", lua: "SHIFT" }
	]

	// The keysym names of what a key types, shifted (US) included.
	readonly property var charNames: ({
		",": "comma", ".": "period", "/": "slash", ";": "semicolon", "'": "apostrophe",
		"[": "bracketleft", "]": "bracketright", "\\": "backslash", "-": "minus", "=": "equal", "`": "grave",
		"<": "comma", ">": "period", "?": "slash", ":": "semicolon", "\"": "apostrophe",
		"{": "bracketleft", "}": "bracketright", "|": "backslash", "_": "minus", "+": "equal", "~": "grave",
		"!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0"
	})

	function chordOf(mask: int, label: string): string {
		return modifiers.filter(m => mask & m.bit).map(m => m.label).concat([label]).join(" + ");
	}

	// Qt's modifiers as Hyprland's mask.
	function maskOf(qtMods: int): int {
		return (qtMods & Qt.MetaModifier ? 64 : 0) | (qtMods & Qt.ControlModifier ? 4 : 0) | (qtMods & Qt.AltModifier ? 8 : 0)
			| (qtMods & Qt.GroupSwitchModifier ? 128 : 0) | (qtMods & Qt.ShiftModifier ? 1 : 0);
	}

	// The bit of a modifier key itself, or 0.
	function modifierBit(key: int): int {
		return key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R ? 64
			: key === Qt.Key_Control ? 4
			: key === Qt.Key_Alt ? 8
			: key === Qt.Key_AltGr ? 128
			: key === Qt.Key_Shift ? 1 : 0;
	}

	// A Qt key as Hyprland names it, or "" for one it cannot be bound to here.
	function keyName(key: int): string {
		if ((key >= 0x30 && key <= 0x39) || (key >= 0x41 && key <= 0x5a))
			return String.fromCharCode(key);
		if (key >= Qt.Key_F1 && key <= Qt.Key_F35)
			return "F" + (key - Qt.Key_F1 + 1);
		var named = {
			[Qt.Key_Return]: "return", [Qt.Key_Enter]: "return", [Qt.Key_Space]: "space", [Qt.Key_Tab]: "Tab",
			[Qt.Key_Backspace]: "BackSpace", [Qt.Key_Escape]: "escape", [Qt.Key_Delete]: "Delete",
			[Qt.Key_Insert]: "Insert", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Page_Up",
			[Qt.Key_PageDown]: "Page_Down", [Qt.Key_Print]: "print", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right",
			[Qt.Key_Up]: "up", [Qt.Key_Down]: "down"
		};
		if (named[key])
			return named[key];
		return key < 0x7f ? (charNames[String.fromCharCode(key)] ?? "") : "";
	}

	function keyLabel(key: string): string {
		return keyNames[key.toLowerCase()] ?? key.toUpperCase();
	}

	// "1..9" for a run of digits, else the keys side by side, the arrows
	// after the letters they stand in for: "H J K L / ← ↓ ↑ →".
	function keysLabel(keys: var): string {
		if (keys.length > 2 && keys.every((k, i) => /^\d$/.test(k) && (i === 0 || Number(k) === Number(keys[i - 1]) + 1)))
			return keys[0] + ".." + keys[keys.length - 1];
		var arrows = keys.filter(k => "←↓↑→".includes(k));
		var rest = keys.filter(k => !arrows.includes(k));
		return rest.length > 0 && arrows.length > 0 ? rest.join(" ") + " / " + arrows.join(" ") : keys.join(" ");
	}

	function parse(binds: var): var {
		var lines = [];
		var byName = {};
		for (const b of binds) {
			var desc = (b.description || "").trim();
			var key = (b.key || "").trim();
			var cut = desc.indexOf(": ");
			if (cut < 0 || key.toLowerCase().startsWith("xf86") || b.submap)
				continue;
			var name = (b.modmask || 0) + desc;
			if (!byName[name]) {
				byName[name] = { id: desc, category: desc.slice(0, cut), action: desc.slice(cut + 2), mask: b.modmask || 0, keys: [] };
				lines.push(byName[name]);
			}
			byName[name].keys.push(key);
		}
		return lines.map(l => {
			var label = keysLabel(l.keys.map(keyLabel));
			return Object.assign(l, {
				label: label,
				chord: chordOf(l.mask, label),
				editable: true,
				modsOnly: l.keys.length > 1 || l.keys[0].startsWith("mouse")
			});
		});
	}

	// What Hyprland no longer lists: the binds taken off here.
	function removedLines(): var {
		return Object.keys(root.saved).filter(id => root.saved[id].off).sort().map(id => ({
			id: id,
			category: "Removed",
			action: id.slice(id.indexOf(": ") + 2),
			from: id.slice(0, id.indexOf(": ")),
			chord: "",
			removed: true
		}));
	}

	function listed(): var {
		return root.parse(root.binds).concat(root.shellEntries.filter(e => !e.special || Specials.list.length > 0)).concat(root.removedLines());
	}

	function reload(): void {
		bindsProc.running = true;
	}

	// The keys a bind is on now, by its description.
	function chordFor(id: string): string {
		return root.entries.find(e => e.id === id)?.chord ?? "";
	}

	function changed(line: var): bool {
		return line.editable === true && root.saved[line.id] !== undefined;
	}

	function custom(line: var): bool {
		return root.saved[line.id]?.run !== undefined;
	}

	// While new keys are pressed, Hyprland's binds rest (the submap of binds.lua), at
	// most 30 s: a shell gone meanwhile does not leave the desktop without keys.
	function capture(on: bool): void {
		Hypr.dispatch(on ? "function() keycapture_n = (keycapture_n or 0) + 1; local n = keycapture_n; "
			+ "hl.dispatch(hl.dsp.submap(\"keycapture\")); hl.timer(function() if keycapture_n == n and hl.get_current_submap() == \"keycapture\" "
			+ "then hl.dispatch(hl.dsp.submap(\"reset\")) end end, { timeout = 30000, type = \"oneshot\" }) end"
			: "hl.dsp.submap(\"reset\")");
	}

	// The line on mask + key (key "" for modsOnly: its own keys), unless another bind
	// has it; true when it moved.
	function rebind(line: var, mask: int, key: string): bool {
		root.lastError = "";
		var keys = (key !== "" ? [key] : line.keys).map(k => k.toLowerCase());
		if (mask === line.mask && (key === "" || (line.keys.length === 1 && line.keys[0].toLowerCase() === keys[0])))
			return false;
		var taken = root.binds.find(b => !b.submap && (b.description || "").trim() !== line.id && (b.modmask || 0) === mask
			&& keys.includes(String(b.key).toLowerCase()));
		if (taken) {
			var what = (taken.description || "").trim();
			root.lastError = chordOf(mask, keyLabel(taken.key)) + " is taken" + (what !== "" ? " by " + what : "");
			return false;
		}
		var next = Object.assign({}, root.saved);
		// `run`: a new one, whose command stays with it.
		next[line.id] = Object.assign({}, line.run ? { run: line.run } : next[line.id]?.run ? { run: next[line.id].run } : {}, {
			mods: modifiers.filter(m => mask & m.bit).map(m => m.lua).join(" + "),
			key: key
		});
		root.saved = next;
		write();
		return true;
	}

	// Back to binds.lua's keys; a new one has none to go back to.
	function reset(line: var): void {
		if (root.saved[line.id] === undefined || custom(line))
			return;
		change(line.id, undefined);
	}

	// A new one goes for good, one of binds.lua's is taken off until reset().
	function remove(line: var): void {
		root.lastError = "";
		change(line.id, custom(line) ? undefined : { off: true });
	}

	function change(id: string, value: var): void {
		var next = Object.assign({}, root.saved);
		if (value === undefined)
			delete next[id];
		else
			next[id] = value;
		root.saved = next;
		write();
	}

	// A new line's description; its keys are for rebind(), `run` the command.
	function newLine(name: string, run: string): var {
		var id = "Custom: " + name;
		if (root.saved[id] !== undefined) {
			root.lastError = name + " is added already";
			return null;
		}
		root.lastError = "";
		return { id: id, category: "Custom", action: name, label: "", mask: -1, keys: [], editable: true, modsOnly: false, run: run };
	}

	// Hyprland reads it again once it is written.
	function write(): void {
		var lines = Object.keys(root.saved).sort().map(k => {
			var e = root.saved[k];
			var fields = e.off ? ["off = true"] : ["mods = " + Hypr.quote(e.mods)].concat(e.key ? ["key = " + Hypr.quote(e.key)] : [], e.run ? ["run = " + Hypr.quote(e.run)] : []);
			return "\t[" + Hypr.quote(k) + "] = { " + fields.join(", ") + " },";
		});
		savedFile.setText("-- Written by the shell's keys list (SUPER + /): binds changed, taken off or added\n"
			+ "-- there (hyprland/binds.lua). A line taken out goes back to the config's.\n"
			+ "return {\n" + lines.join("\n") + (lines.length > 0 ? "\n" : "") + "}\n");
	}

	Component.onCompleted: reload()

	Connections {
		target: Hyprland
		function onRawEvent(ev) {
			if (ev.name === "configreloaded")
				root.reload();
		}
	}

	Process {
		id: bindsProc
		command: ["hyprctl", "-j", "binds"]
		stdout: StdioCollector {
			onStreamFinished: {
				var binds = [];
				try {
					binds = JSON.parse(this.text);
				} catch (e) {}
				root.binds = binds;
				root.entries = root.listed();
				root.loaded = true;
			}
		}
	}

	// Each line as write() makes it: ["desc"] = { mods = "...", key = "...", run = "..." },
	FileView {
		id: savedFile
		path: root.savedPath
		blockLoading: true
		printErrors: false
		onSaved: Hypr.reload()
		onLoaded: {
			var found = {};
			for (const line of this.text().split("\n")) {
				var m = /^\s*\[("(?:[^"\\]|\\.)*")\]\s*=\s*\{(.*)\},?\s*$/.exec(line);
				if (!m)
					continue;
				var e = { key: "" };
				for (const f of m[2].matchAll(/(\w+)\s*=\s*("(?:[^"\\]|\\.)*"|true)/g))
					e[f[1]] = JSON.parse(f[2]);
				found[JSON.parse(m[1])] = e;
			}
			root.saved = found;
		}
	}
}
