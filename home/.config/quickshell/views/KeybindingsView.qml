import ".."
import "../widgets"
import Quickshell
import QtQuick
import QtQuick.Layouts

// Every key bind Hyprland reports, and what hyprctl cannot see: gestures, the
// bar's mouse handling and the keys inside the shell's own panels. Opened from
// a panel ("?"), it starts filtered to that panel's section and goes back to
// the panel when it closes.
OverlayWindow {
	id: window

	panel: "keybindings"
	namespace: "quickshell-keybindings"
	backdropColor: Qt.rgba(0, 0, 0, 0.55)
	card: sheetCard

	property string query: ""
	property string returnTo: ""
	property string returnMode: ""
	property var columns: [[], [], []]

	onOpened: mode => {
		window.returnTo = mode ? Panels.previous : "";
		window.returnMode = mode ? Panels.previousMode : "";
		search.clear();
		if (mode)
			search.complete(mode);
		search.focusInput();
		flick.contentY = 0;
		window.rebuildColumns();
	}
	onDismissRequested: {
		if (window.returnTo !== "")
			Panels.open(window.returnTo, window.returnMode);
		else
			Panels.close("keybindings");
	}

	readonly property var categoryOrder: [
		"Essential",
		"Window Management",
		"Navigation & Workspaces",
		"Special Workspaces",
		"System & Tools",
		"Capture & OCR",
		"Notifications",
		"Keyboard",
		"Mouse",
		"Gestures",
		"Bar",
		"Panels",
		"Launcher",
		"Quick actions",
		"Wi-Fi & Bluetooth",
		"Weather"
	]

	// What the shell does on its own, out of hyprctl's sight. `order` keeps
	// them in the sequence written here.
	readonly property var staticEntries: [
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
		{ category: "Bar", chord: "RIGHT-CLICK STATUS", action: "Energy use (jolt)" },
		{ category: "Bar", chord: "CLICK EMPTY BAR", action: "Close the panel or special workspace" },

		{ category: "Panels", chord: "ESC / Q", action: "Close (or go back a page)" },
		{ category: "Panels", chord: "J / K  ↓ / ↑", action: "Move the selection" },
		{ category: "Panels", chord: "?", action: "The keys of the open panel" },

		{ category: "Launcher", chord: "2+2", action: "Calculate; Enter copies the result" },
		{ category: "Launcher", chord: ">", action: "Every command; Enter runs it in a terminal" },
		{ category: "Launcher", chord: "TAB", action: "Complete the command" },
		{ category: "Launcher", chord: "CTRL + J / K", action: "Move the selection" },
		{ category: "Launcher", chord: "ENTER, ENTER", action: "Log out, reboot or power off" },

		{ category: "Quick actions", chord: "H / L", action: "Volume or brightness down / up" },
		{ category: "Quick actions", chord: "ENTER", action: "Open the tile's page" },
		{ category: "Quick actions", chord: "SPACE", action: "Switch the tile on or off" },
		{ category: "Quick actions", chord: "W / B", action: "Wi-Fi / Bluetooth page" },
		{ category: "Quick actions", chord: "SHIFT + W / B", action: "Turn Wi-Fi / Bluetooth on or off" },
		{ category: "Quick actions", chord: "S / A / D", action: "Battery saver / Keep awake / Do not disturb" },
		{ category: "Quick actions", chord: "C", action: "Capture: screenshot, recording, OCR, color" },
		{ category: "Quick actions", chord: "P", action: "Power: lock, suspend, reboot, power off" },
		{ category: "Quick actions", chord: "M", action: "Mute" },

		{ category: "Wi-Fi & Bluetooth", chord: "ENTER", action: "Connect or disconnect" },
		{ category: "Wi-Fi & Bluetooth", chord: "SPACE", action: "Turn the radio on or off" },
		{ category: "Wi-Fi & Bluetooth", chord: "R", action: "Scan again" },
		{ category: "Wi-Fi & Bluetooth", chord: "X, X", action: "Forget the network or device" },
		{ category: "Wi-Fi & Bluetooth", chord: "H / BACKSPACE", action: "Back" },

		{ category: "Notifications", chord: "ENTER", action: "Open the selected one (center)" },
		{ category: "Notifications", chord: "X", action: "Dismiss the selected one (center)" },

		{ category: "Weather", chord: "E / ENTER", action: "Change the location" }
	].map((e, i) => Object.assign({ order: i }, e))

	readonly property var swapEntry: ({ category: "Keyboard", chord: "LEFT ALT", action: "Works as SUPER (Alt and Super swapped)", order: -1 })

	readonly property var categoryRules: [
		{ cat: "Capture & OCR", match: ["screenshot", "dictation"] },
		{ cat: "Essential", match: ["terminal", "browser", "keybindings", "launcher"] },
		{ cat: "Notifications", match: ["notification"] },
		// hyprland.lua describes every special workspace toggle as "Show <app>".
		{ cat: "Special Workspaces", match: ["show "] },
		{ cat: "System & Tools", match: ["lock system", "emoji", "quick actions", "weather", "clipboard", "wallpaper"] },
		{ cat: "Window Management", match: ["close window", "fullscreen", "split", "swap window", "resize window"] },
		{ cat: "Navigation & Workspaces", match: ["focus", "workspace"] }
	]

	function categoryOf(bind) {
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
		"Essential": { "Terminal": 1, "Browser": 2, "Launcher": 3, "Keybindings": 4 },
		"Capture & OCR": { "Screenshot (region)": 1, "Screenshot (full)": 2, "Dictation": 3 },
		"Notifications": { "Toggle notification center": 1, "Close latest notification": 2 }
	})

	function itemRank(item) {
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

	// The binds of Hyprland folded for the sheet: the nine workspace binds of
	// each kind become one line.
	readonly property var entries: {
		var list = [];
		var folded = {};
		var binds = Keybinds.binds;
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
		list = list.concat(staticEntries);
		if (Keybinds.altSwapped)
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

	onEntriesChanged: rebuildColumns()

	function matches(e, q) {
		return e.category.toLowerCase().indexOf(q) !== -1
			|| e.action.toLowerCase().indexOf(q) !== -1
			|| e.chord.toLowerCase().indexOf(q) !== -1;
	}

	function rebuildColumns() {
		var q = query.trim().toLowerCase();
		var map = {};
		var order = [];
		for (var i = 0; i < entries.length; i++) {
			var e = entries[i];
			if (q !== "" && !matches(e, q))
				continue;
			if (!map[e.category]) {
				map[e.category] = [];
				order.push(e.category);
			}
			map[e.category].push(e);
		}
		var cols = [[], [], []];
		var heights = [0, 0, 0];
		for (var n = 0; n < order.length; n++) {
			var shortest = 0;
			if (heights[1] < heights[shortest]) shortest = 1;
			if (heights[2] < heights[shortest]) shortest = 2;
			cols[shortest].push({ category: order[n], items: map[order[n]] });
			heights[shortest] += map[order[n]].length + 2;
		}
		columns = cols;
	}

	readonly property int shownCount: columns.reduce((sum, col) => sum + col.reduce((s, g) => s + g.items.length, 0), 0)

	function statusText() {
		if (!Keybinds.loaded)
			return "Loading keybindings...";
		if (query.trim() !== "")
			return shownCount + " of " + entries.length;
		return entries.length + " entries";
	}

	Rectangle {
		id: sheetCard
		anchors.centerIn: parent
		width: Math.min(1440, window.width - 96)
		height: Math.min(900, window.height - 96)
		color: Theme.panel(Theme.bgMain)
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingWindow
		clip: true

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

				SearchBar {
					id: search
					Layout.preferredWidth: 420
					Layout.preferredHeight: 44
					icon: "keyboard"
					placeholder: "Search keys..."
					onTextChanged: {
						window.query = text;
						window.rebuildColumns();
					}
					onStepped: delta => flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + delta * 80))
					onCancelled: window.dismissRequested()
				}

				Text {
					Layout.fillWidth: true
					text: window.statusText()
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeSmall + 1
					color: Theme.textDim
					elide: Text.ElideRight
				}

				Text {
					text: "? in a panel shows its keys"
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeSmall + 1
					color: Theme.textDim
				}
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 1
				color: Theme.border
			}

			Flickable {
				id: flick
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
							Layout.preferredWidth: 1
							Layout.alignment: Qt.AlignTop
							spacing: 20

							Repeater {
								model: modelData

								delegate: ColumnLayout {
									id: group
									required property var modelData
									// The shell's own handling, set apart from Hyprland's binds.
									readonly property bool shellSide: window.categoryOrder.indexOf(modelData.category) >= window.categoryOrder.indexOf("Keyboard")
									Layout.fillWidth: true
									spacing: 6

									RowLayout {
										Layout.fillWidth: true
										spacing: 12

										Text {
											text: group.modelData.category.toUpperCase()
											font.family: Theme.fontMono
											font.pixelSize: Theme.fontSizeSmall + 1
											font.bold: true
											color: group.shellSide ? Theme.accentGreen : Theme.accentPurple
										}

										Rectangle {
											Layout.fillWidth: true
											Layout.preferredHeight: 1
											color: Theme.border
											opacity: 0.7
										}
									}

									Repeater {
										model: group.modelData.items

										delegate: RowLayout {
											required property var modelData
											Layout.fillWidth: true
											spacing: 12

											Text {
												Layout.preferredWidth: 240
												Layout.alignment: Qt.AlignTop
												font.family: Theme.fontMono
												font.pixelSize: Theme.fontSizeSmall + 2
												font.bold: true
												color: group.shellSide ? Theme.accentGreen : Theme.accentBlue
												elide: Text.ElideRight
												text: modelData.chord || ""
											}

											Text {
												Layout.fillWidth: true
												Layout.alignment: Qt.AlignTop
												font.family: Theme.fontMono
												font.pixelSize: Theme.fontSizeSmall + 2
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
				visible: Keybinds.loaded && window.shownCount === 0
				Layout.alignment: Qt.AlignCenter
				font.family: Theme.fontMono
				font.pixelSize: Theme.fontSize + 2
				color: Theme.textDim
				text: Keybinds.binds.length === 0 ? "No keybindings found (is Hyprland running?)" : "Nothing matches"
			}
		}
	}
}
