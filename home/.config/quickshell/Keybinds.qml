pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// The key binds Hyprland reports and the keys the shell handles itself, for
// the launcher's keys list and the chords shown next to what a bind also does.
// hyprland.lua makes the binds in the order the list shows them, each
// described as "Section: what it does".
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
		"mouse:272": "LEFT DRAG",
		"mouse:273": "RIGHT DRAG",
		"mouse:274": "MIDDLE CLICK",
		"mouse_down": "SCROLL ↓",
		"mouse_up": "SCROLL ↑"
	})

	// What the shell does on its own, out of hyprctl's sight, and shown nowhere
	// else: not the keys printed in the panels, nor Esc and J / K, which every
	// panel takes.
	readonly property var shellEntries: [
		{ category: "Mouse", chord: "RIGHT-CLICK BAR ICON", action: "Close a special workspace" },
		{ category: "Gestures", chord: "3 FINGERS ↔", action: "Switch workspace" },
		{ category: "Gestures", chord: "3 FINGERS ↑", action: "Open the last special workspace" },
		{ category: "Gestures", chord: "3 FINGERS ↓", action: "Hide the special workspace" },
		{ category: "Launcher", chord: "2+2", action: "Calculate" },
		{ category: "Launcher", chord: "/", action: "Files and folders in ~" },
		{ category: "Launcher", chord: ">", action: "Run every command (in terminal)" }
	]

	function chordOf(mask: int, label: string): string {
		var mods = [];
		if (mask & 64)
			mods.push("SUPER");
		if (mask & 4)
			mods.push("CTRL");
		if (mask & 8)
			mods.push("ALT");
		if (mask & 1)
			mods.push("SHIFT");
		return mods.concat([label]).join(" + ");
	}

	function keyLabel(key: string): string {
		return keyNames[key.toLowerCase()] ?? key.toUpperCase();
	}

	// "1..9" for a run of digits, else the keys side by side: "H J K L".
	function keysLabel(keys: var): string {
		if (keys.length > 2 && keys.every((k, i) => /^\d$/.test(k) && (i === 0 || Number(k) === Number(keys[i - 1]) + 1)))
			return keys[0] + ".." + keys[keys.length - 1];
		return keys.join(" ");
	}

	// The chord bound to `action` (a description without its section), or "".
	function chord(action: string): string {
		return action ? entries.find(e => e.action === action)?.chord ?? "" : "";
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
