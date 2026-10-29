pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// Hyprland's binds and the shell's own keys, for the launcher's keys list.
Singleton {
	id: root

	// { category, action, chord }, one line for the binds that share a
	// description and modifiers (SUPER + 1..9); media keys and switches left out.
	property var entries: []
	property bool loaded: false

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
		"mouse:272": "LEFT DRAG",
		"mouse:273": "RIGHT DRAG",
		"mouse_down": "SCROLL ↓",
		"mouse_up": "SCROLL ↑"
	})

	// The shell's own keys, shown nowhere else (not Esc and J / K, which every panel takes).
	readonly property var shellEntries: [
		{ category: "Mouse", chord: "RIGHT-CLICK BAR ICON", action: "Close a special workspace" },
		{ category: "Gestures", chord: "3 FINGERS ↔", action: "Switch workspace" },
		{ category: "Gestures", chord: "3 FINGERS ↑", action: "Open the last special workspace" },
		{ category: "Gestures", chord: "3 FINGERS ↓", action: "Hide the special workspace" }
	]

	function chordOf(mask: int, label: string): string {
		var mods = [];
		if (mask & 64)
			mods.push("SUPER");
		if (mask & 4)
			mods.push("CTRL");
		if (mask & 8)
			mods.push("ALT");
		if (mask & 128)
			mods.push("ALTGR");
		if (mask & 1)
			mods.push("SHIFT");
		return mods.concat([label]).join(" + ");
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
			if (cut < 0 || key.toLowerCase().startsWith("xf86"))
				continue;
			var name = (b.modmask || 0) + desc;
			if (!byName[name]) {
				byName[name] = { category: desc.slice(0, cut), action: desc.slice(cut + 2), mask: b.modmask || 0, keys: [] };
				lines.push(byName[name]);
			}
			byName[name].keys.push(keyLabel(key));
		}
		return lines.map(l => ({ category: l.category, action: l.action, chord: chordOf(l.mask, keysLabel(l.keys)) }));
	}

	function reload(): void {
		bindsProc.running = true;
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
				root.entries = root.parse(binds).concat(root.shellEntries);
				root.loaded = true;
			}
		}
	}
}
