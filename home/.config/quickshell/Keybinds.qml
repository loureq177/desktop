pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// The key binds Hyprland reports, each with the chord the shell shows for it,
// and the keys the shell handles itself. Binds are found by their description:
// the launcher and the bar's tooltips show the chord of the action they offer,
// and the launcher's keys list them all, with its actions.
Singleton {
	id: root

	// { chord, action, key, mask, mouse }, in Hyprland's order; media keys and
	// switches left out.
	property var binds: []
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

	function chordFor(mask: int, key: string): string {
		return chordOf(mask, keyNames[key.toLowerCase()] ?? key.toUpperCase());
	}

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

	// The chord bound to `action`, or "" when nothing is.
	function chord(action: string): string {
		if (!action)
			return "";
		var hit = binds.find(b => b.action === action);
		return hit ? hit.chord : "";
	}

	// What the shell does on its own, out of hyprctl's sight, and shown
	// nowhere else: not the keys printed in the panels (the tiles of Actions,
	// Wi-Fi, Bluetooth, notifications, weather), nor Esc and J / K,
	// which every panel takes. `order` keeps them in the sequence written here.
	// The H J K L lines stand for the twelve binds of the direction fold below.
	readonly property var shellEntries: [
		{ category: "Windows", chord: "SUPER + H J K L", action: "Left, down, up, right" },
		{ category: "Windows", chord: "SUPER + SHIFT + H J K L", action: "Window move" },
		{ category: "Windows", chord: "SUPER + CTRL + H J K L", action: "Window resize" },

		{ category: "Gestures", chord: "3 FINGERS ↔", action: "Switch workspace" },
		{ category: "Gestures", chord: "3 FINGERS ↑", action: "Open the last special workspace" },
		{ category: "Gestures", chord: "3 FINGERS ↓", action: "Hide the special workspace" },

		{ category: "Mouse", chord: "RIGHT-CLICK BAR ICON", action: "Close a special workspace" },

		{ category: "Launcher", chord: "2+2", action: "Calculate" },
		{ category: "Launcher", chord: "/", action: "Files and folders in ~" },
		{ category: "Launcher", chord: ">", action: "Run every command (in terminal)" }
	].map((e, i) => Object.assign({ order: i }, e))

	readonly property var categoryOrder: [
		"Essential",
		"Windows",
		"Special Workspaces",
		"System & Tools",
		"Session",
		"Capture",
		"Notifications",
		"Mouse",
		"Gestures",
		"Launcher"
	]

	readonly property var categoryRules: [
		{ cat: "Capture", match: ["screenshot", "dictation"] },
		{ cat: "Essential", match: ["browser", "terminal", "launcher"] },
		{ cat: "Notifications", match: ["notification"] },
		// hyprland.lua describes every special workspace toggle as "Show <app>".
		{ cat: "Special Workspaces", match: ["show "] },
		{ cat: "Session", match: ["lock system"] },
		{ cat: "System & Tools", match: ["emoji", "actions", "weather", "clipboard", "wallpaper"] },
		{ cat: "Windows", match: ["window", "fullscreen", "floating", "focus", "workspace"] }
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
		"Essential": { "Browser": 1, "Terminal": 2, "Launcher": 3 },
		"Capture": { "Screenshot": 1, "Screenshot of the screen": 2, "Dictation": 3 },
		"Mouse": { "Move window": 1 },
		"Notifications": { "Toggle notification center": 1, "Close latest notification": 2 },
		// After the H J K L lines (orders 0..2): moving around, then the window itself.
		"Windows": {
			"Focus previous window": 10,
			"Switch to workspace 1..9": 11,
			"Move window to workspace 1..9": 12,
			"Close window": 20,
			"Toggle fullscreen": 21,
			"Toggle window split": 22,
			"Toggle floating": 23
		}
	})

	function itemRank(item: var): int {
		if (item.order !== undefined)
			return item.order;
		var act = item.action || "";
		if (rankPriorities[item.category] && rankPriorities[item.category][act])
			return rankPriorities[item.category][act];
		return 50;
	}

	// Binds that differ only in a digit or a direction: each set folds into one
	// line, `key` standing for all of its keys. `rule` ones are left out: the
	// H J K L lines of shellEntries already say them.
	readonly property var folds: [
		{ re: /^(Switch to workspace|Move window to workspace) \d$/, action: m => m[1] + " 1..9", key: "1..9" },
		{ re: /^(Focus|Swap window|Resize window) (left|down|up|right)$/, action: m => m[1] + " left / down / up / right", key: "H J K L", rule: true }
	]

	// { category, chord, action } of every bind and shell key, in categoryOrder,
	// with the binds of each fold on one line.
	readonly property var entries: {
		var list = [];
		var folded = {};
		for (var i = 0; i < binds.length; i++) {
			var b = binds[i];
			var action = b.action;
			var chord = b.chord;
			var skip = false;
			for (var j = 0; j < folds.length; j++) {
				var m = action.match(folds[j].re);
				if (!m)
					continue;
				action = folds[j].action(m);
				chord = chordOf(b.mask, folds[j].key);
				skip = folds[j].rule === true;
				break;
			}
			// A mouse twin of a key says nothing new (Toggle floating).
			if (skip || (b.mouse && binds.some(o => !o.mouse && o.action === b.action)))
				continue;
			if (folded[action + chord])
				continue;
			folded[action + chord] = true;
			var category = categoryOf(b);
			// The section already says what "Show" would.
			if (category === "Special Workspaces")
				action = action.replace(/^Show /, "");
			list.push({ category: category, chord: chord, action: action });
		}
		list = list.concat(shellEntries);
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
							mask: b.modmask || 0,
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
}
