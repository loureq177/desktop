import ".."
import "../widgets"
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
	id: window

	visible: false
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell"

	screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

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
		"Notifications",
		"Media & Hardware"
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
		},
		{
			category: "Gestures",
			chord: "Touchpad 4-Finger Drag",
			action: "Move active window",
			dispatcher: "",
			arg: "",
			order: 5,
			keywords: "gesture gestures gesty drag move window swipe 4 fingers trackpad touchpad gładzik float przesuń okno"
		}
	]

	function getCategory(desc, chord) {
		var d = (desc || "").toLowerCase();
		if (d.indexOf("screenshot") !== -1 || d.indexOf("screen recording") !== -1 || d.indexOf("ocr") !== -1)
			return "Capture & OCR";
		if (d.indexOf("volume") !== -1 || d.indexOf("brightness") !== -1 || d.indexOf("microphone") !== -1)
			return "Media & Hardware";
		if (d.indexOf("terminal") !== -1 || d.indexOf("browser") !== -1 || d.indexOf("launch apps") !== -1
			|| d.indexOf("keybindings") !== -1 || d.indexOf("system menu") !== -1)
			return "Essential";
		if (d.indexOf("notification") !== -1 || d.indexOf("do not disturb") !== -1)
			return "Notifications";
		if (d.indexOf("copy") !== -1 || d.indexOf("paste") !== -1 || d.indexOf("cut") !== -1
			|| d.indexOf("select all") !== -1 || d.indexOf("clipboard") !== -1)
			return "Clipboard & Selection";
		if (d.indexOf("calendar") !== -1 || d.indexOf("tasks") !== -1 || d.indexOf("whatsapp") !== -1
			|| d.indexOf("mail") !== -1 || d.indexOf("discord") !== -1 || d.indexOf("spotify") !== -1
			|| d.indexOf("gemini") !== -1 || d.indexOf("yazi") !== -1 || d.indexOf("notes") !== -1)
			return "Special Workspaces";
		if (d.indexOf("system update") !== -1 || d.indexOf("lock system") !== -1 || d.indexOf("idle inhibit") !== -1
			|| d.indexOf("color picker") !== -1 || d.indexOf("run commands") !== -1 || d.indexOf("emoji") !== -1
			|| d.indexOf("audio controls") !== -1 || d.indexOf("bluetooth") !== -1 || d.indexOf("calculator") !== -1
			|| d.indexOf("wifi") !== -1 || d.indexOf("activity monitor") !== -1 || d.indexOf("touchpad") !== -1)
			return "System & Tools";
		if (d.indexOf("close window") !== -1 || d.indexOf("fullscreen") !== -1 || d.indexOf("split") !== -1
			|| d.indexOf("floating") !== -1 || d.indexOf("swap window") !== -1 || d.indexOf("resize window") !== -1
			|| d.indexOf("drag window") !== -1)
			return "Window Management";
		if (d.indexOf("focus") !== -1 || d.indexOf("workspace") !== -1)
			return "Navigation & Workspaces";
		return "Essential";
	}

	function getKeywords(cat, desc, chord) {
		var kw = [cat.toLowerCase(), (desc || "").toLowerCase(), (chord || "").toLowerCase()];
		if (cat === "Navigation & Workspaces") {
			kw.push("pulpit pulpity przełącz nawigacja okna 1 2 3 4 5 6 7 8 9 [1..9]");
		} else if (cat === "Window Management") {
			kw.push("okno okna zarządzanie przesuń zamknij");
		} else if (cat === "Special Workspaces") {
			kw.push("pulpit specjalny scratchpad skróty");
		} else if (cat === "Capture & OCR") {
			kw.push("zrzut ekranu nagrywanie przechwytywanie");
		} else if (cat === "Clipboard & Selection") {
			kw.push("schowek historia kopiuj wklej zaznacz");
		} else if (cat === "Media & Hardware") {
			kw.push("dźwięk głośność jasność audio");
		} else if (cat === "Notifications") {
			kw.push("powiadomienia powiadomienie 1 2 3 akcja");
		} else if (cat === "System & Tools") {
			kw.push("system narzędzia aktualizacja blokada");
		}
		return kw.join(" ");
	}

	function itemRank(item) {
		var cat = item.category;
		var catIdx = categoryOrder.indexOf(cat);
		if (catIdx === -1) catIdx = 999;
		var act = item.action || "";
		var subRank = 50;

		if (cat === "Gestures") {
			subRank = item.order || 50;
		} else if (cat === "Essential") {
			var ep = { "Terminal": 1, "Browser": 2, "Launch apps": 3, "Keybindings": 4, "System menu": 5 };
			subRank = ep[act] || 50;
		} else if (cat === "Window Management") {
			var wp = {
				"Close window": 1, "Toggle fullscreen": 2, "Toggle window split": 3, "Toggle floating": 4,
				"Drag window": 5, "Resize window (mouse)": 6,
				"Swap window left": 10, "Swap window down": 11, "Swap window up": 12, "Swap window right": 13,
				"Resize window left": 20, "Resize window down": 21, "Resize window up": 22, "Resize window right": 23
			};
			subRank = wp[act] || 50;
		} else if (cat === "Navigation & Workspaces") {
			var fp = { "Focus left": 1, "Focus down": 2, "Focus up": 3, "Focus right": 4 };
			if (fp[act]) {
				subRank = fp[act];
			} else if (act.indexOf("Switch to workspace") !== -1) {
				subRank = 10;
			} else if (act.indexOf("Move window to workspace") !== -1) {
				subRank = 20;
			} else if (act.indexOf("Move window silently") !== -1) {
				subRank = 30;
			}
		} else if (cat === "Capture & OCR") {
			var cp = {
				"Screenshot (region)": 1, "Screenshot (fullscreen)": 2,
				"Screen recording (region)": 3, "Screen recording (fullscreen)": 4,
				"OCR from screen": 5
			};
			subRank = cp[act] || 50;
		} else if (cat === "Clipboard & Selection") {
			var clp = { "Clipboard history": 1, "Copy": 2, "Paste": 3, "Cut": 4, "Select all": 5 };
			subRank = clp[act] || 50;
		} else if (cat === "Media & Hardware") {
			var mp = {
				"Volume up": 1, "Volume down": 2, "Volume mute": 3, "Microphone mute": 4,
				"Brightness up": 5, "Brightness down": 6
			};
			subRank = mp[act] || 50;
		} else if (cat === "Notifications") {
			var np = {
				"Close latest notification": 1, "Notification action": 2,
				"Notification action 1..3": 3,
				"Toggle Do Not Disturb": 4, "Toggle notification center": 5
			};
			subRank = np[act] || 50;
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

		// Find what items are currently visible in the list viewport
		var topIndex = list.indexAt(20, list.contentY + 20);
		var bottomIndex = list.indexAt(20, list.contentY + list.height - 20);

		// If user scrolled manually so currentIndex is outside visible range:
		if (topIndex >= 0 && (currentIndex < topIndex || (bottomIndex >= 0 && currentIndex > bottomIndex))) {
			if (delta > 0) {
				currentIndex = Math.min(n - 1, topIndex + 1);
			} else {
				currentIndex = Math.max(0, (bottomIndex >= 0 ? bottomIndex : topIndex) - 1);
			}
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
		} else if (entry.dispatcher !== "" && entry.dispatcher !== "lua" && entry.dispatcher !== "__lua" && entry.arg !== "") {
			Quickshell.execDetached(["hyprctl", "dispatch", entry.dispatcher, entry.arg]);
			return true;
		} else if (entry.dispatcher !== "" && entry.dispatcher !== "lua" && entry.dispatcher !== "__lua") {
			Quickshell.execDetached(["hyprctl", "dispatch", entry.dispatcher]);
			return true;
		}

		// Gestures, ranges, Lua closures, or internal Hyprland actions are displayed for reference.
		return true;
	}

	function open() {
		query = "";
		search.clear();
		if (entries.length === 0 && !loader.running) {
			loading = true;
			loader.running = true;
		} else {
			refilter();
		}
		window.visible = true;
		search.focusInput();
	}

	function close() {
		window.visible = false;
	}

	function toggle() {
		if (window.visible)
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

					// Start with static gesture definitions
					for (var g = 0; g < window.staticGestures.length; g++) {
						list.push(window.staticGestures[g]);
					}

					var keyMap = {
						"comma": ",",
						"period": ".",
						"slash": "/",
						"space": "SPACE",
						"return": "RETURN",
						"escape": "ESC",
						"print": "PRINT",
						"mouse:272": "LMB (Drag)",
						"mouse:273": "RMB (Drag)",
						"xf86audioraisevolume": "Volume Up",
						"xf86audiolowervolume": "Volume Down",
						"xf86audiomute": "Volume Mute",
						"xf86audiomicmute": "Mic Mute",
						"xf86monbrightnessup": "Brightness Up",
						"xf86monbrightnessdown": "Brightness Down",
						"xf86touchpadtoggle": "Touchpad Toggle",
						"xf86touchpadon": "Touchpad On",
						"xf86touchpadoff": "Touchpad Off",
						"[1..9]": "[1..9]",
						"[1..3]": "[1..3]"
					};

					var workspaceSwitchSeen = false;
					var workspaceMoveSeen = false;
					var workspaceMoveSilentSeen = false;
					var notifActionSeen = false;

					for (var i = 0; i < binds.length; i++) {
						var b = binds[i];
						var desc = (b.description || "").trim();
						if (!desc) continue;

						var mask = b.modmask || 0;
						var rawKey = (b.key || "").trim();

						// Collapse 1..9 workspace binds into single clean entries
						if (desc.indexOf("Switch to workspace ") === 0) {
							if (workspaceSwitchSeen) continue;
							workspaceSwitchSeen = true;
							desc = "Switch to workspace 1..9";
							rawKey = "[1..9]";
						} else if (desc.indexOf("Move window silently to workspace ") === 0) {
							if (workspaceMoveSilentSeen) continue;
							workspaceMoveSilentSeen = true;
							desc = "Move window silently to workspace 1..9";
							rawKey = "[1..9]";
						} else if (desc.indexOf("Move window to workspace ") === 0) {
							if (workspaceMoveSeen) continue;
							workspaceMoveSeen = true;
							desc = "Move window to workspace 1..9";
							rawKey = "[1..9]";
						} else if (desc.indexOf("Notification action ") === 0) {
							if (notifActionSeen) continue;
							notifActionSeen = true;
							desc = "Notification action 1..3";
							rawKey = "[1..3]";
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
							var cat = window.getCategory(desc, chord);
							list.push({
								category: cat,
								chord: chord,
								action: desc,
								dispatcher: (rawKey === "[1..9]" || rawKey === "[1..3]") ? "" : (b.dispatcher || ""),
								arg: (rawKey === "[1..9]" || rawKey === "[1..3]") ? "" : (b.arg || ""),
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

	// Full-screen dim backdrop matching Hyprland's special workspace dimming effect
	Rectangle {
		id: backdrop
		anchors.fill: parent
		color: Theme.backdropColor

		MouseArea {
			anchors.fill: parent
			onClicked: window.close()
		}
	}

	Rectangle {
		id: dialogCard
		anchors.centerIn: parent
		width: Math.min(1060, parent.width - 64)
		height: Math.min(680, parent.height - 64)
		color: Theme.bgMain
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingWindow
		clip: true

		MouseArea {
			anchors.fill: parent
		}

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: Theme.paddingCard
			spacing: 12

			SearchBar {
				id: search
				Layout.fillWidth: true
				Layout.preferredHeight: 48
				title: "Keys"
				placeholder: "Search keybindings & gestures..."
				onTextChanged: {
					window.query = text;
					window.refilter();
				}
				onAccepted: window.activate()
				onCancelled: window.close()
				onStepped: delta => window.move(delta)
			}

			Item {
				Layout.fillWidth: true
				Layout.fillHeight: true

				ListView {
					id: list
					anchors.fill: parent
					clip: true
					flickDeceleration: 350
					maximumFlickVelocity: 5000
					boundsBehavior: Flickable.StopAtBounds
					pixelAligned: true
					spacing: 2
					model: window.filtered
					currentIndex: window.currentIndex

					// Kinetic momentum engine for touchpad on Linux/Wayland
					property real lastScrollTime: 0
					property real scrollVelocity: 0

					WheelHandler {
						target: null
						onWheel: event => {
							var now = Date.now();
							var dt = (now - list.lastScrollTime) / 1000.0;
							var dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : (event.angleDelta.y * 1.25);

							if (dt > 0.003 && dt < 0.12) {
								var instV = dy / dt;
								list.scrollVelocity = list.scrollVelocity * 0.3 + instV * 0.7;
							} else {
								list.scrollVelocity = dy / 0.02;
							}
							list.lastScrollTime = now;
							flingTimer.restart();
						}
					}

					Timer {
						id: flingTimer
						interval: 40
						repeat: false
						onTriggered: {
							var v = list.scrollVelocity;
							list.scrollVelocity = 0;
							if (Math.abs(v) > 100) {
								if ((v < 0 && !list.atYEnd) || (v > 0 && !list.atYBeginning)) {
									var clampedV = Math.max(-5000, Math.min(5000, v));
									list.flick(0, clampedV);
								}
							}
						}
					}

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

						Behavior on color {
							ColorAnimation { duration: 100 }
						}

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

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 1
				color: Theme.border
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 32
				color: "transparent"
				Text {
					anchors.fill: parent
					verticalAlignment: Text.AlignVCenter
					horizontalAlignment: Text.AlignRight
					font.family: Theme.fontMono
					font.pointSize: 12
					color: window.lastError !== "" ? Theme.critical : Theme.textDim
					elide: Text.ElideRight
					text: window.lastError !== "" ? window.lastError : window.statusText()
				}
			}
		}
	}
}
