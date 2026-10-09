// Keybindings cheatsheet: fullscreen blurred overlay showing every
// shortcut at once, grouped by category in balanced columns.
// Read-only: Esc or click outside closes. No search, no dispatch.
// Toggle via IPC: `qs ipc call shell toggle keybindings ''` (SUPER + /).
import ".."
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
	id: window

	property bool shown: false
	signal opened()
	signal dismissed()

	function open() {
		if (entries.length === 0 && !loader.running)
			loader.running = true;
		window.shown = true;
	}

	function close() {
		window.shown = false;
	}

	function toggle() {
		if (window.shown)
			close();
		else
			open();
	}

	onShownChanged: {
		if (shown) {
			exitAnim.stop();
			enterAnim.restart();
			window.opened();
		} else {
			enterAnim.stop();
			exitAnim.restart();
			window.dismissed();
		}
	}

	ParallelAnimation {
		id: enterAnim

		NumberAnimation {
			target: backdrop
			property: "opacity"
			from: 0.0
			to: 1.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}

		NumberAnimation {
			target: sheetCard
			property: "opacity"
			from: 0.0
			to: 1.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}

		NumberAnimation {
			target: sheetCard
			property: "scale"
			from: 0.96
			to: 1.0
			duration: Theme.animNormal
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
	}

	ParallelAnimation {
		id: exitAnim

		NumberAnimation {
			target: backdrop
			property: "opacity"
			to: 0.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}

		NumberAnimation {
			target: sheetCard
			property: "opacity"
			to: 0.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}

		NumberAnimation {
			target: sheetCard
			property: "scale"
			to: 0.97
			duration: Theme.animFast
			easing.type: Easing.InCubic
		}
	}

	visible: shown || exitAnim.running
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell-keybindings"

	screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	Shortcut {
		sequences: ["Esc"]
		enabled: window.visible
		onActivated: window.close()
	}

	property var entries: []
	// Balanced into 3 columns: each item is { category, items }.
	property var columns: [[], [], []]
	property bool loading: true

	readonly property var categoryOrder: [
		"Gestures",
		"Essential",
		"Window Management",
		"Navigation & Workspaces",
		"Special Workspaces",
		"System & Tools",
		"Capture & OCR",
		"Clipboard & Selection",
		"Notifications"
	]

	readonly property var staticGestures: [
		{
			category: "Gestures",
			chord: "Touchpad 3-Finger ↔",
			action: "Switch workspace",
			order: 1
		},
		{
			category: "Gestures",
			chord: "Touchpad 3-Finger ↑",
			action: "Open special workspace",
			order: 2
		},
		{
			category: "Gestures",
			chord: "Touchpad 3-Finger ↓",
			action: "Hide special workspace",
			order: 3
		},
		{
			category: "Gestures",
			chord: "Touchpad 3-Finger ↔ (Special)",
			action: "Cycle special workspaces",
			order: 4
		}
	]

	readonly property var categoryRules: [
		{ cat: "Capture & OCR", match: ["screenshot", "screen recording", "ocr", "color picker", "dictation"] },
		{ cat: "Essential", match: ["terminal", "browser", "launch apps", "keybindings"] },
		{ cat: "Notifications", match: ["notification", "do not disturb"] },
		{ cat: "Clipboard & Selection", match: ["clipboard"] },
		{ cat: "Special Workspaces", match: ["calendar", "tasks", "whatsapp", "mail", "discord", "spotify", "gemini", "yazi", "notes", "calculator", "activity monitor"] },
		{ cat: "System & Tools", match: ["system update", "lock system", "idle inhibit", "run commands", "emoji", "audio controls", "bluetooth", "wifi", "power", "battery", "jolt", "touchpad", "quick settings", "quick actions", "weather"] },
		{ cat: "Window Management", match: ["close window", "fullscreen", "split", "floating", "swap window", "resize window", "drag window"] },
		{ cat: "Navigation & Workspaces", match: ["focus", "workspace"] }
	]

	function getCategory(desc) {
		var d = (desc || "").toLowerCase();
		for (var i = 0; i < categoryRules.length; i++) {
			var rule = categoryRules[i];
			for (var j = 0; j < rule.match.length; j++) {
				if (d.indexOf(rule.match[j]) !== -1)
					return rule.cat;
			}
		}
		return "Essential";
	}

	readonly property var rankPriorities: ({
		"Essential": { "Terminal": 1, "Browser": 2, "Launch apps": 3, "Keybindings": 4 },
		"Capture & OCR": { "Screenshot (region)": 1, "Screenshot (full)": 2, "Color picker": 3, "OCR from screen": 4, "Dictation": 5 },
		"Clipboard & Selection": { "Clipboard history": 1 },
		"Notifications": { "Close latest notification": 1, "Toggle notification center": 2 }
	})

	function itemRank(item) {
		var catIdx = categoryOrder.indexOf(item.category);
		if (catIdx === -1) catIdx = 999;
		var act = item.action || "";
		var subRank = 50;

		if (item.category === "Gestures") {
			subRank = item.order || 50;
		} else if (rankPriorities[item.category] && rankPriorities[item.category][act]) {
			subRank = rankPriorities[item.category][act];
		} else if (item.category === "Window Management") {
			if (act.indexOf("Close") === 0) subRank = 1;
			else if (act.indexOf("Toggle fullscreen") === 0) subRank = 2;
			else if (act.indexOf("Swap") === 0) subRank = 10;
			else if (act.indexOf("Resize") === 0) subRank = 20;
		} else if (item.category === "Navigation & Workspaces") {
			if (act.indexOf("Focus") === 0) subRank = 1;
			else if (act.indexOf("Switch to workspace") !== -1) subRank = 10;
			else if (act.indexOf("Move window to workspace") !== -1) subRank = 20;
			else if (act.indexOf("Move window silently") !== -1) subRank = 30;
		}

		return (catIdx * 1000) + subRank;
	}

	// Group entries by categoryOrder, then greedily balance the groups
	// across 3 columns by row count so everything fits on one screen.
	function rebuildColumns() {
		var map = {};
		for (var i = 0; i < entries.length; i++) {
			var e = entries[i];
			var cat = e.category || "Essential";
			if (!map[cat])
				map[cat] = [];
			map[cat].push(e);
		}
		var groups = [];
		for (var g = 0; g < categoryOrder.length; g++) {
			var c = categoryOrder[g];
			if (map[c] && map[c].length > 0)
				groups.push({ category: c, items: map[c] });
		}
		for (var k in map) {
			if (categoryOrder.indexOf(k) === -1 && map[k].length > 0)
				groups.push({ category: k, items: map[k] });
		}
		var cols = [[], [], []];
		var heights = [0, 0, 0];
		for (var n = 0; n < groups.length; n++) {
			var shortest = 0;
			if (heights[1] < heights[shortest]) shortest = 1;
			if (heights[2] < heights[shortest]) shortest = 2;
			cols[shortest].push(groups[n]);
			heights[shortest] += groups[n].items.length + 1;
		}
		columns = cols;
	}

	function statusText() {
		if (loading) return "Loading keybindings...";
		var gestureCount = 0;
		for (var i = 0; i < entries.length; i++) {
			if (entries[i].category === "Gestures") gestureCount++;
		}
		return entries.length + " items (" + (entries.length - gestureCount) + " keys, " + gestureCount + " gestures)";
	}

	Process {
		id: loader
		command: ["hyprctl", "-j", "binds"]
		running: true
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					var binds = JSON.parse(this.text);
					var seen = {};
					var list = [];

					for (var g = 0; g < window.staticGestures.length; g++)
						list.push(window.staticGestures[g]);

					var keyMap = {
						"comma": ",", "period": ".", "slash": "/", "space": "SPACE",
						"return": "RETURN", "escape": "ESC", "print": "PRINT",
						"[1..9]": "[1..9]", "fn + f10": "Fn + F10"
					};

					var workspaceSwitchSeen = false;
					var workspaceMoveSeen = false;

					for (var i = 0; i < binds.length; i++) {
						var b = binds[i];
						var desc = (b.description || "").trim();
						if (!desc) continue;

						var mask = b.modmask || 0;
						var rawKey = (b.key || "").trim();
						var rawLower = rawKey.toLowerCase();

						// Filter out hardware keys (XF86*) and hardware switches, except touchpad toggle (Fn + F10)
						if (rawLower === "xf86touchpadtoggle") {
							rawKey = "fn + f10";
						} else if (rawLower.indexOf("xf86") !== -1 || rawLower.indexOf("switch:") !== -1) {
							continue;
						}

						if (desc.indexOf("Switch to workspace ") === 0) {
							if (workspaceSwitchSeen) continue;
							workspaceSwitchSeen = true;
							desc = "Switch to workspace 1..9";
							rawKey = "[1..9]";
						} else if (desc.indexOf("Move window to workspace ") === 0) {
							if (workspaceMoveSeen) continue;
							workspaceMoveSeen = true;
							desc = "Move window to workspace 1..9";
							rawKey = "[1..9]";
						}

						var mods = [];
						if (mask & 64) mods.push("SUPER");
						if (mask & 4) mods.push("CTRL");
						if (mask & 8) mods.push("ALT");
						if (mask & 1) mods.push("SHIFT");

						var keyLabel = keyMap[rawKey.toLowerCase()] || keyMap[rawKey] || rawKey.toUpperCase();
						var chord = mods.concat([keyLabel]).join(" + ");
						var keyId = chord + ":" + desc;

						if (!seen[keyId]) {
							seen[keyId] = true;
							var cat = window.getCategory(desc);
							list.push({
								category: cat,
								chord: chord,
								action: desc
							});
						}
					}

					list.sort(function(a, b) {
						var rankA = window.itemRank(a);
						var rankB = window.itemRank(b);
						if (rankA !== rankB) return rankA - rankB;
						var cComp = (a.chord || "").localeCompare(b.chord || "");
						if (cComp !== 0) return cComp;
						return (a.action || "").localeCompare(b.action || "");
					});

					window.entries = list;
				} catch (e) {
					window.entries = [].concat(window.staticGestures);
				}
				window.loading = false;
				window.rebuildColumns();
			}
		}
	}

	// Full-screen dim backdrop (translucent so Hyprland blurs behind it).
	Rectangle {
		id: backdrop
		anchors.fill: parent
		color: Qt.rgba(0, 0, 0, 0.55)

		MouseArea {
			anchors.fill: parent
			enabled: window.shown
			// Dismiss on press, same layer-surface split reason as the
			// CenterModal/SideDrawer backdrops.
			onPressed: window.close()
		}
	}

	// Centered cheatsheet card.
	Rectangle {
		id: sheetCard
		anchors.centerIn: parent
		width: Math.min(1440, window.width - 96)
		height: Math.min(900, window.height - 96)
		color: Theme.bgMain
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingWindow
		clip: true

		// Absorb clicks inside the card so they don't reach the backdrop.
		MouseArea {
			anchors.fill: parent
			enabled: window.shown
		}

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: Theme.paddingCard + 8
			spacing: 12

			RowLayout {
				Layout.fillWidth: true
				spacing: 16

				Text {
					text: "Keybindings"
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSize + 2
					font.bold: true
					color: Theme.textMain
				}

				Text {
					Layout.fillWidth: true
					text: window.statusText()
					font.family: Theme.fontMono
					font.pointSize: Theme.fontSizeSmall
					color: Theme.textDim
					elide: Text.ElideRight
				}

				Text {
					text: "esc closes"
					font.family: Theme.fontMono
					font.pointSize: Theme.fontSizeSmall
					color: Theme.textMuted
				}
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 1
				color: Theme.border
			}

			Flickable {
				Layout.fillWidth: true
				Layout.fillHeight: true
				clip: true
				contentWidth: width
				contentHeight: sheetGrid.implicitHeight
				boundsBehavior: Flickable.DragAndOvershootBounds
				flickDeceleration: Theme.flickDecel
				maximumFlickVelocity: Theme.maxFlickVel
				pixelAligned: true

				RowLayout {
					id: sheetGrid
					width: parent.width
					anchors.top: parent.top
					spacing: 32

					Repeater {
						model: window.columns

						delegate: ColumnLayout {
							required property var modelData
							Layout.fillWidth: true
							Layout.alignment: Qt.AlignTop
							spacing: 20

							Repeater {
								model: modelData

								delegate: ColumnLayout {
									required property var modelData
									Layout.fillWidth: true
									spacing: 6

									RowLayout {
										Layout.fillWidth: true
										spacing: 12

										Text {
											text: modelData.category.toUpperCase()
											font.family: Theme.fontMono
											font.pointSize: 11.5
											font.bold: true
											color: modelData.category === "Gestures" ? Theme.accentGreen : Theme.accentPurple
										}

										Rectangle {
											Layout.fillWidth: true
											Layout.preferredHeight: 1
											color: Theme.border
											opacity: 0.7
										}
									}

									Repeater {
										model: modelData.items

										delegate: RowLayout {
											required property var modelData
											Layout.fillWidth: true
											spacing: 12

											Text {
												Layout.preferredWidth: 168
												Layout.alignment: Qt.AlignTop
												font.family: Theme.fontMono
												font.pointSize: 12
												font.bold: true
												color: modelData.category === "Gestures" ? Theme.accentGreen : Theme.accentBlue
												elide: Text.ElideRight
												text: modelData.chord || ""
											}

											Text {
												Layout.fillWidth: true
												Layout.alignment: Qt.AlignTop
												font.family: Theme.fontMono
												font.pointSize: 12
												color: Theme.textMain
												wrapMode: Text.WrapAtWordBoundaryOrAnywhere
												maximumLineCount: 2
												elide: Text.ElideRight
												text: modelData.action || ""
											}
										}
									}
								}
							}
						}
					}
				}
			}

			Text {
				visible: !window.loading && window.entries.length === 0
				Layout.alignment: Qt.AlignCenter
				font.family: Theme.fontMono
				font.pointSize: 14
				color: Theme.textDim
				text: "No keybindings found (is Hyprland running?)"
			}
		}
	}
}
