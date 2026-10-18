pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// The key binds Hyprland reports, each with the chord the shell shows for it,
// and the keys the shell handles itself. Binds are found by their description:
// the launcher and the bar's tooltips show the chord of the action they offer,
// and the launcher's actions list them all.
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

	// What the shell does on its own, out of hyprctl's sight. `order` keeps
	// them in the sequence written here.
	readonly property var shellEntries: [
		{ category: "Gestures", chord: "3 FINGERS ↔", action: "Switch workspace" },
		{ category: "Gestures", chord: "3 FINGERS ↑", action: "Open the last special workspace" },
		{ category: "Gestures", chord: "3 FINGERS ↓", action: "Hide the special workspace" },
		{ category: "Gestures", chord: "3 FINGERS ↔", action: "Cycle special workspaces (while one is open)" },

		{ category: "Keyboard", chord: "CAPS LOCK", action: "Esc when tapped, Ctrl when held" },

		{ category: "Bar", chord: "CLICK ICON", action: "Open or hide a special workspace" },
		{ category: "Bar", chord: "RIGHT-CLICK ICON", action: "Close it" },
		{ category: "Bar", chord: "SCROLL DOTS", action: "Switch workspace" },
		{ category: "Bar", chord: "SCROLL ICONS", action: "Cycle special workspaces" },
		{ category: "Bar", chord: "CLICK MEMORY", action: "Activity Monitor" },
		{ category: "Bar", chord: "CLICK CLOCK", action: "Calendar" },
		{ category: "Bar", chord: "MIDDLE-CLICK WEATHER", action: "Refresh the forecast" },
		{ category: "Bar", chord: "CLICK EMPTY BAR", action: "Close the panel or special workspace" },

		{ category: "Panels", chord: "ESC / Q", action: "Close (or go back a page)" },
		{ category: "Panels", chord: "J / K", action: "Move the selection" },

		{ category: "Launcher", chord: "2+2", action: "Calculate; Enter copies the result" },
		{ category: "Launcher", chord: ">", action: "Every command; Enter runs it in a terminal" },
		{ category: "Launcher", chord: ":", action: "Emoji" },
		{ category: "Launcher", chord: "?", action: "Every action and key" },
		{ category: "Launcher", chord: "TAB", action: "Complete the command" },
		{ category: "Launcher", chord: "CTRL + J / K", action: "Move the selection" },
		{ category: "Launcher", chord: "BACKSPACE", action: "Back to the apps (from emoji, clipboard, actions)" },
		{ category: "Launcher", chord: "ENTER, ENTER", action: "Log out, reboot or power off" },

		{ category: "Quick settings", chord: "H / L", action: "Volume or brightness down / up" },
		{ category: "Quick settings", chord: "ENTER", action: "Open the tile's page" },
		{ category: "Quick settings", chord: "SPACE", action: "Switch the tile on or off" },
		{ category: "Quick settings", chord: "W / B", action: "Wi-Fi / Bluetooth page" },
		{ category: "Quick settings", chord: "SHIFT + W / B", action: "Turn Wi-Fi / Bluetooth on or off" },
		{ category: "Quick settings", chord: "S / A / D", action: "Battery saver / Keep awake / DND" },
		{ category: "Quick settings", chord: "C", action: "Capture: screenshot, recording, OCR, color" },
		{ category: "Quick settings", chord: "P", action: "Power: lock, suspend, reboot, power off" },
		{ category: "Quick settings", chord: "M", action: "Mute" },

		{ category: "Wi-Fi & Bluetooth", chord: "ENTER", action: "Connect or disconnect" },
		{ category: "Wi-Fi & Bluetooth", chord: "SPACE", action: "Turn the radio on or off" },
		{ category: "Wi-Fi & Bluetooth", chord: "R", action: "Scan again" },
		{ category: "Wi-Fi & Bluetooth", chord: "X, X", action: "Forget the network or device" },
		{ category: "Wi-Fi & Bluetooth", chord: "H / BACKSPACE", action: "Back" },

		{ category: "Notifications", chord: "ENTER", action: "Open the selected one" },
		{ category: "Notifications", chord: "X", action: "Dismiss the selected one" },

		{ category: "Weather", chord: "E / ENTER", action: "Change the location" }
	].map((e, i) => Object.assign({ order: i }, e))

	readonly property var swapEntry: ({ category: "Keyboard", chord: "LEFT ALT", action: "Works as SUPER (Alt and Super swapped)", order: -1 })

	readonly property var categoryOrder: [
		"Essential",
		"Window Management",
		"Navigation & Workspaces",
		"Special Workspaces",
		"System & Tools",
		"Session",
		"Capture & OCR",
		"Notifications",
		"Keyboard",
		"Mouse",
		"Gestures",
		"Bar",
		"Panels",
		"Launcher",
		"Quick settings",
		"Wi-Fi & Bluetooth",
		"Weather"
	]

	readonly property var categoryRules: [
		{ cat: "Capture & OCR", match: ["screenshot", "dictation"] },
		{ cat: "Essential", match: ["terminal", "browser", "actions and keys", "launcher"] },
		{ cat: "Notifications", match: ["notification"] },
		// hyprland.lua describes every special workspace toggle as "Show <app>".
		{ cat: "Special Workspaces", match: ["show "] },
		{ cat: "Session", match: ["lock system"] },
		{ cat: "System & Tools", match: ["emoji", "quick settings", "weather", "clipboard", "wallpaper"] },
		{ cat: "Window Management", match: ["close window", "fullscreen", "split", "floating", "swap window", "resize window"] },
		{ cat: "Navigation & Workspaces", match: ["focus", "workspace"] }
	]

	function categoryOf(bind: var): string {
		if (bind.mouse)
			return "Mouse";
		var d = bind.action.toLowerCase();
		for (var i = 0; i < categoryRules.length; i++) {
			var rule = categoryRules[i];
			for (var j = 0; j < rule.match.length; j++) {
				if (d.indexOf(rule.match[j]) !== -1)
					return rule.cat;
			}
		}
		return "System & Tools";
	}

	readonly property var rankPriorities: ({
		"Essential": { "Terminal": 1, "Browser": 2, "Launcher": 3, "Actions and keys": 4 },
		"Capture & OCR": { "Screenshot (region)": 1, "Screenshot (full)": 2, "Dictation": 3 },
		"Notifications": { "Toggle notification center": 1, "Close latest notification": 2 }
	})

	function itemRank(item: var): int {
		if (item.order !== undefined)
			return item.order;
		var act = item.action || "";
		if (rankPriorities[item.category] && rankPriorities[item.category][act])
			return rankPriorities[item.category][act];
		if (item.category === "Window Management") {
			if (act.indexOf("Close") === 0) return 1;
			if (act.indexOf("Toggle fullscreen") === 0) return 2;
			if (act.indexOf("Swap") === 0) return 10;
			if (act.indexOf("Resize") === 0) return 20;
		} else if (item.category === "Navigation & Workspaces") {
			if (act.indexOf("Focus") === 0) return 1;
			if (act.indexOf("Switch to workspace") !== -1) return 10;
			if (act.indexOf("Move window to workspace") !== -1) return 20;
		}
		return 50;
	}

	// { category, chord, action } of every bind and shell key, in categoryOrder.
	// The nine workspace binds of each kind fold into one line.
	readonly property var entries: {
		var list = [];
		var folded = {};
		for (var i = 0; i < binds.length; i++) {
			var b = binds[i];
			var action = b.action;
			var chord = b.chord;
			var m = action.match(/^(Switch to workspace|Move window to workspace) \d$/);
			if (m) {
				if (folded[m[1]])
					continue;
				folded[m[1]] = true;
				action = m[1] + " 1..9";
				chord = chord.replace(/\d$/, "1..9");
			}
			list.push({ category: categoryOf(b), chord: chord, action: action });
		}
		list = list.concat(shellEntries);
		if (altSwapped)
			list.push(swapEntry);
		list.sort((a, b) => {
			var ca = categoryOrder.indexOf(a.category);
			var cb = categoryOrder.indexOf(b.category);
			if (ca !== cb)
				return ca - cb;
			var ra = itemRank(a);
			var rb = itemRank(b);
			if (ra !== rb)
				return ra - rb;
			return a.chord.localeCompare(b.chord);
		});
		return list;
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
