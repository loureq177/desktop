pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// The key binds Hyprland reports, each with the chord the shell shows for it.
// Binds are found by their description: the launcher and the bar's tooltips
// show the chord of the action they offer, the keybindings sheet lists them all.
Singleton {
	id: root

	// { chord, action, key, mouse }, in Hyprland's order; media keys and
	// switches left out.
	property var binds: []
	property bool loaded: false
	// input:kb_options swaps left Alt and Super, so SUPER is the key labelled Alt.
	property bool altSwapped: false

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

	function chordFor(mask: int, key: string): string {
		var mods = [];
		if (mask & 64)
			mods.push("SUPER");
		if (mask & 4)
			mods.push("CTRL");
		if (mask & 8)
			mods.push("ALT");
		if (mask & 1)
			mods.push("SHIFT");
		var label = keyNames[key.toLowerCase()] ?? key.toUpperCase();
		return mods.concat([label]).join(" + ");
	}

	// The chord bound to `action`, or "" when nothing is.
	function chord(action: string): string {
		if (!action)
			return "";
		var hit = binds.find(b => b.action === action);
		return hit ? hit.chord : "";
	}

	function reload(): void {
		bindsProc.running = true;
		optionProc.running = true;
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
				var list = [];
				try {
					var raw = JSON.parse(this.text);
					for (var i = 0; i < raw.length; i++) {
						var b = raw[i];
						var action = (b.description || "").trim();
						var key = (b.key || "").trim();
						var lower = key.toLowerCase();
						if (!action || lower.indexOf("xf86") !== -1 || lower.indexOf("switch:") === 0)
							continue;
						list.push({
							chord: root.chordFor(b.modmask || 0, key),
							action: action,
							key: key,
							mouse: lower.indexOf("mouse") === 0
						});
					}
				} catch (e) {
					list = [];
				}
				root.binds = list;
				root.loaded = true;
			}
		}
	}

	Process {
		id: optionProc
		command: ["hyprctl", "-j", "getoption", "input:kb_options"]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					root.altSwapped = String(JSON.parse(this.text).str ?? "").indexOf("swap_lalt_lwin") !== -1;
				} catch (e) {
					root.altSwapped = false;
				}
			}
		}
	}
}
