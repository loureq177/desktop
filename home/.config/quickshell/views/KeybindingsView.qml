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

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell"

	screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

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

	function refilter() {
		lastError = "";
		var q = query.toLowerCase().trim();
		var out = [];
		for (var i = 0; i < entries.length; i++) {
			var e = entries[i];
			if (q === "" || (e.action && e.action.toLowerCase().indexOf(q) !== -1)
				|| (e.chord && e.chord.toLowerCase().indexOf(q) !== -1))
			{
				out.push(e);
			}
		}
		filtered = out;
		currentIndex = 0;
	}

	function move(delta) {
		var n = filtered.length;
		if (n === 0) {
			currentIndex = 0;
			return;
		}
		currentIndex = Math.max(0, Math.min(n - 1, currentIndex + delta));
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
		} else if (entry.dispatcher !== "" && entry.dispatcher !== "lua" && entry.arg !== "") {
			Quickshell.execDetached(["hyprctl", "dispatch", entry.dispatcher, entry.arg]);
			return true;
		} else if (entry.dispatcher !== "" && entry.dispatcher !== "lua") {
			Quickshell.execDetached(["hyprctl", "dispatch", entry.dispatcher]);
			return true;
		}

		// Lua closures or internal Hyprland actions are displayed for reference.
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
		return n === 1 ? "1 keybinding" : n + " keybindings";
	}

	onCurrentIndexChanged: {
		list.positionViewAtIndex(currentIndex, ListView.Contain);
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
					var keyMap = { "comma": ",", "period": ".", "slash": "/", "space": "SPACE", "return": "RETURN", "escape": "ESC" };

					for (var i = 0; i < binds.length; i++) {
						var b = binds[i];
						var desc = (b.description || "").trim();
						if (!desc) continue;

						var mask = b.modmask || 0;
						var mods = [];
						if (mask & 64) mods.push("SUPER");
						if (mask & 4) mods.push("CTRL");
						if (mask & 8) mods.push("ALT");
						if (mask & 1) mods.push("SHIFT");

						var rawKey = (b.key || "").trim();
						var keyLabel = keyMap[rawKey.toLowerCase()] || rawKey.toUpperCase();
						var chord = mods.concat([keyLabel]).join(" + ");
						var keyId = chord + ":" + desc;

						if (!seen[keyId]) {
							seen[keyId] = true;
							list.push({ chord: chord, action: desc, dispatcher: b.dispatcher || "", arg: b.arg || "" });
						}
					}
					list.sort(function(a, b) { return a.chord.localeCompare(b.chord); });
					window.entries = list;
				} catch (e) {
					window.entries = [];
					window.lastError = "Could not query hyprctl binds";
				}
				window.loading = false;
				window.refilter();
			}
		}
	}

	// Dim backdrop; clicking outside the dialog card closes.
	MouseArea {
		anchors.fill: parent
		onClicked: window.close()

		Rectangle {
			anchors.fill: parent
			color: Theme.backdropColor
		}

		Rectangle {
			id: dialogCard
			anchors.centerIn: parent
			width: Theme.windowWidth
			height: Theme.windowHeight
			color: Theme.bgMain
			border.color: Theme.border
			border.width: Theme.borderSize
			radius: Theme.roundingWindow

			MouseArea {
				anchors.fill: parent
			}

			ColumnLayout {
				anchors.fill: parent
				spacing: 0

				SearchBar {
					id: search
					Layout.fillWidth: true
					Layout.preferredHeight: 64
					title: "Keys"
					placeholder: "Search keybindings..."
					onTextChanged: {
						window.query = text;
						window.refilter();
					}
					onAccepted: window.activate()
					onCancelled: window.close()
					onStepped: delta => window.move(delta)
				}

				Rectangle {
					Layout.fillWidth: true
					Layout.preferredHeight: 1
					color: Theme.border
				}

				Item {
					Layout.fillWidth: true
					Layout.fillHeight: true
					Layout.margins: Theme.paddingCard

					ListView {
						id: list
						anchors.fill: parent
						clip: true
						flickDeceleration: 600
						maximumFlickVelocity: 4000
						spacing: 2
						model: window.filtered
						delegate: Rectangle {
							width: list.width
							height: 40
							color: index === window.currentIndex ? Theme.selectionBg : "transparent"
							border.color: index === window.currentIndex ? Theme.selectionBorder : "transparent"
							border.width: 1
							radius: Theme.roundingElement

							Behavior on color {
								ColorAnimation { duration: 100 }
							}

							RowLayout {
								anchors.fill: parent
								anchors.leftMargin: 12
								anchors.rightMargin: 12
								spacing: 16

								Text {
									Layout.preferredWidth: 280
									Layout.alignment: Qt.AlignVCenter
									font.family: Theme.fontMono
									font.pointSize: Theme.fontSizeBar
									color: Theme.accentBlue
									elide: Text.ElideRight
									text: modelData.chord || ""
								}

								Text {
									Layout.fillWidth: true
									Layout.alignment: Qt.AlignVCenter
									font.family: Theme.fontMono
									font.pointSize: Theme.fontSizeBar
									color: Theme.textMain
									elide: Text.ElideRight
									text: modelData.action || ""
								}
							}

							MouseArea {
								anchors.fill: parent
								hoverEnabled: true
								onEntered: window.currentIndex = index
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
						font.pointSize: Theme.fontSizeBar
						color: Theme.textDim
						text: "No keybindings match"
					}
				}

				Rectangle {
					Layout.fillWidth: true
					Layout.preferredHeight: 1
					color: Theme.border
				}

				Rectangle {
					Layout.fillWidth: true
					Layout.preferredHeight: 36
					color: "transparent"
					Text {
						anchors.fill: parent
						anchors.leftMargin: Theme.paddingCard
						anchors.rightMargin: Theme.paddingCard
						verticalAlignment: Text.AlignVCenter
						horizontalAlignment: Text.AlignRight
						font.family: Theme.fontMono
						font.pointSize: Theme.fontSizeSmall
						color: window.lastError !== "" ? Theme.critical : Theme.textDim
						elide: Text.ElideRight
						text: window.lastError !== "" ? window.lastError : window.statusText()
					}
				}
			}
		}
	}
}
