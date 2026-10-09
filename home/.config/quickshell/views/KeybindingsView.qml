import ".."
import "../widgets"
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

CenterModal {
	id: window

	searchTitle: "Keys"
	searchPlaceholder: "Search..."
	showFooter: true
	statusText: window.statusText()
	errorText: window.lastError

	onSearchQueryChanged: {
		window.query = searchQuery;
		window.refilter();
	}
	onSearchAccepted: window.activate()
	onSearchStepped: delta => window.move(delta)

	property var entries: []
	property var filtered: []
	property int currentIndex: 0
	property string query: ""
	property string lastError: ""
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
			dispatcher: "",
			arg: "",
			order: 1,
			keywords: "gesture gestures gesty swipe trackpad touchpad gładzik workspace switch pulpit przełącz"
		},
		{
			category: "Gestures",
			chord: "Touchpad 3-Finger ↑",
			action: "Open special workspace",
			dispatcher: "",
			arg: "",
			order: 2,
			keywords: "gesture gestures gesty swipe trackpad touchpad gładzik special scratchpad open otwórz"
		},
		{
			category: "Gestures",
			chord: "Touchpad 3-Finger ↓",
			action: "Hide special workspace",
			dispatcher: "",
			arg: "",
			order: 3,
			keywords: "gesture gestures gesty swipe trackpad touchpad gładzik special scratchpad hide close ukryj zamknij"
		},
		{
			category: "Gestures",
			chord: "Touchpad 3-Finger ↔ (Special)",
			action: "Cycle special workspaces",
			dispatcher: "",
			arg: "",
			order: 4,
			keywords: "gesture gestures gesty swipe trackpad touchpad gładzik special scratchpad cycle next prev przełącz"
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

	readonly property var categoryKeywords: ({
		"Navigation & Workspaces": "pulpit pulpity przełącz nawigacja okna 1 2 3 4 5 6 7 8 9 [1..9]",
		"Window Management": "okno okna zarządzanie przesuń zamknij",
		"Special Workspaces": "pulpit specjalny scratchpad skróty",
		"Capture & OCR": "zrzut ekranu nagrywanie przechwytywanie kolor ocr dyktowanie",
		"Clipboard & Selection": "schowek historia kopiuj wklej zaznacz",
		"Notifications": "powiadomienia powiadomienie",
		"System & Tools": "system narzędzia aktualizacja blokada pogoda"
	})

	function getKeywords(cat, desc, chord) {
		var extra = categoryKeywords[cat] || "";
		return [cat, desc, chord, extra].join(" ").toLowerCase();
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

	function refilter() {
		lastError = "";
		var q = query.toLowerCase().trim();
		var out = [];
		for (var i = 0; i < entries.length; i++) {
			var e = entries[i];
			if (q === ""
				|| (e.action && e.action.toLowerCase().indexOf(q) !== -1)
				|| (e.chord && e.chord.toLowerCase().indexOf(q) !== -1)
				|| (e.category && e.category.toLowerCase().indexOf(q) !== -1)
				|| (e.keywords && e.keywords.toLowerCase().indexOf(q) !== -1))
			{
				out.push(e);
			}
		}
		filtered = out;
		currentIndex = 0;
		list.positionViewAtBeginning();
	}

	function move(delta) {
		var n = filtered.length;
		if (n === 0) {
			currentIndex = 0;
			return;
		}

		var topIndex = list.indexAt(20, list.contentY + 20);
		var bottomIndex = list.indexAt(20, list.contentY + list.height - 20);

		if (topIndex >= 0 && (currentIndex < topIndex || (bottomIndex >= 0 && currentIndex > bottomIndex))) {
			if (delta > 0)
				currentIndex = Math.min(n - 1, topIndex + 1);
			else
				currentIndex = Math.max(0, (bottomIndex >= 0 ? bottomIndex : topIndex) - 1);
		} else {
			currentIndex = Math.max(0, Math.min(n - 1, currentIndex + delta));
		}

		list.positionViewAtIndex(currentIndex, ListView.Contain);
	}

	function dispatch(entry) {
		lastError = "";
		if (!entry) {
			lastError = "Nothing selected";
			return false;
		}

		if (entry.dispatcher === "exec" && entry.arg !== "") {
			Quickshell.execDetached(["hyprctl", "dispatch", "exec", entry.arg]);
			return true;
		} else if (entry.dispatcher === "__lua" && entry.arg !== "") {
			Quickshell.execDetached(["hyprctl", "dispatch", "__lua", entry.arg]);
			return true;
		} else if (entry.dispatcher !== "" && entry.dispatcher !== "lua" && entry.dispatcher !== "__lua" && entry.arg !== "") {
			Quickshell.execDetached(["hyprctl", "dispatch", entry.dispatcher, entry.arg]);
			return true;
		} else if (entry.dispatcher !== "" && entry.dispatcher !== "lua" && entry.dispatcher !== "__lua") {
			Quickshell.execDetached(["hyprctl", "dispatch", entry.dispatcher]);
			return true;
		}

		return true;
	}

	function open() {
		query = "";
		searchBar.clear();
		if (entries.length === 0 && !loader.running) {
			loading = true;
			loader.running = true;
		} else {
			refilter();
		}
		window.shown = true;
		searchBar.focusInput();
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

	function activate() {
		if (dispatch(filtered[currentIndex]))
			close();
	}

	function statusText() {
		if (loading) return "Loading keybindings...";
		var n = filtered.length;
		var gestureCount = 0;
		for (var i = 0; i < filtered.length; i++) {
			if (filtered[i].category === "Gestures") gestureCount++;
		}
		var keyCount = n - gestureCount;
		if (n === 0) return "No matches";
		return n + " items (" + keyCount + " keys, " + gestureCount + " gestures)";
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
								action: desc,
								dispatcher: (rawKey === "[1..9]") ? "" : (b.dispatcher || ""),
								arg: (rawKey === "[1..9]") ? "" : (b.arg || ""),
								keywords: window.getKeywords(cat, desc, chord)
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
					window.lastError = "Could not query hyprctl binds";
				}
				window.loading = false;
				window.refilter();
			}
		}
	}

	// Main body slot for CenterModal
	Item {
		id: contentBox
		anchors.fill: parent

		ListView {
			id: list
			anchors.fill: parent
			clip: true
			boundsBehavior: Flickable.DragAndOvershootBounds
			flickDeceleration: Theme.flickDecel
			maximumFlickVelocity: Theme.maxFlickVel
			pixelAligned: true
			spacing: 2
			model: window.filtered
			currentIndex: window.currentIndex

			section.property: "category"
			section.criteria: ViewSection.FullString
			section.labelPositioning: ViewSection.InlineLabels
			section.delegate: Component {
				Item {
					width: list.width
					height: 36

					RowLayout {
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.bottom: parent.bottom
						anchors.bottomMargin: 4
						anchors.leftMargin: 8
						anchors.rightMargin: 8
						spacing: 12

						Text {
							text: section.toUpperCase()
							font.family: Theme.fontMono
							font.pointSize: 11.5
							font.bold: true
							color: section === "Gestures" ? Theme.accentGreen : Theme.accentPurple
						}

						Rectangle {
							Layout.fillWidth: true
							Layout.preferredHeight: 1
							color: Theme.border
							opacity: 0.7
						}
					}
				}
			}

			delegate: Rectangle {
				width: list.width
				height: 38
				color: index === window.currentIndex ? Theme.selectionBg : "transparent"
				border.color: index === window.currentIndex ? Theme.selectionBorder : "transparent"
				border.width: 1
				radius: Theme.roundingElement

				Behavior on color { ColorAnimation { duration: 100 } }

				RowLayout {
					anchors.fill: parent
					anchors.leftMargin: 14
					anchors.rightMargin: 14
					spacing: 16

					Text {
						Layout.preferredWidth: 340
						Layout.alignment: Qt.AlignVCenter
						font.family: Theme.fontMono
						font.pointSize: 13.5
						font.bold: true
						color: modelData.category === "Gestures" ? Theme.accentGreen : Theme.accentBlue
						elide: Text.ElideRight
						text: modelData.chord || ""
					}

					Text {
						Layout.fillWidth: true
						Layout.alignment: Qt.AlignVCenter
						font.family: Theme.fontMono
						font.pointSize: 13.5
						color: Theme.textMain
						elide: Text.ElideRight
						text: modelData.action || ""
					}
				}

				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					onEntered: {
						if (!list.moving && !list.flicking)
							window.currentIndex = index;
					}
					onClicked: {
						window.currentIndex = index;
						window.activate();
					}
				}
			}
		}

		Text {
			visible: !window.loading && window.filtered.length === 0
			anchors.centerIn: parent
			font.family: Theme.fontMono
			font.pointSize: 14
			color: Theme.textDim
			text: "No keybindings or gestures match"
		}
	}
}
