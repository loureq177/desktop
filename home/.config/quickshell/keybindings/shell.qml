// Keybindings cheatsheet popup (SUPER + ?).
// Standalone Quickshell config, launched on demand by `keybindings-menu`:
//   qs -n -p ~/.config/quickshell/keybindings/shell.qml
// Data comes from `keybindings-data --json` (hyprctl binds + Lua fallback).
// Enter dispatches the selected binding like Omarchy, Esc closes.
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
	id: root

	property var entries: []
	property var filtered: []
	property int currentIndex: 0

	function refilter() {
		var q = searchInput.text.toLowerCase();
		var out = [];
		for (var i = 0; i < entries.length; i++) {
			var e = entries[i];
			if (q === "" || e.display.toLowerCase().indexOf(q) !== -1)
				out.push(e);
		}
		filtered = out;
		currentIndex = 0;
	}

	function wtypeArgsForChord(chord) {
		if (!chord)
			return null;
		var upper = chord.toUpperCase();
		if (upper.indexOf("MOUSE") !== -1 || upper.indexOf("CODE:") !== -1)
			return null;
		var rawParts = chord.split("+");
		if (rawParts.length === 0)
			return null;
		var rawKey = rawParts[rawParts.length - 1].trim();
		if (rawKey === "")
			return null;
		var modMap = {
			"SUPER": "logo",
			"SHIFT": "shift",
			"CTRL": "ctrl",
			"CONTROL": "ctrl",
			"ALT": "alt"
		};
		var args = [];
		for (var i = 0; i < rawParts.length - 1; i++) {
			var toks = rawParts[i].trim().split(/\s+/);
			for (var j = 0; j < toks.length; j++) {
				if (toks[j] === "")
					continue;
				var m = modMap[toks[j].toUpperCase()];
				if (!m)
					return null;
				args.push("-M", m);
			}
		}
		var k;
		if (rawKey.indexOf("XF86") === 0)
			k = rawKey;
		else {
			k = rawKey.toLowerCase();
			var keyMap = {
				"~": "grave",
				"grave": "grave",
				"comma": "comma",
				"period": "period",
				"minus": "minus",
				"equal": "equal",
				"slash": "slash",
				"space": "space",
				"return": "Return",
				"enter": "Return",
				"escape": "Escape",
				"esc": "Escape",
				"print": "Print",
				"tab": "Tab",
				"backspace": "BackSpace",
				"delete": "Delete",
				"up": "Up",
				"down": "Down",
				"left": "Left",
				"right": "Right"
			};
			if (keyMap[k])
				k = keyMap[k];
			else if (k.length === 1)
				k = k.toLowerCase();
			else if (!/^[A-Za-z0-9_]+$/.test(k))
				return null;
		}
		args.push("-k", k);
		return args;
	}

	function dispatch(entry) {
		if (!entry)
			return;
		var cmd = [];
		if (entry.dispatcher === "exec" && entry.arg !== "")
			cmd = ["hyprctl", "dispatch", "exec", entry.arg];
		else if (entry.dispatcher !== "" && entry.dispatcher !== "lua" && entry.arg !== "")
			cmd = ["hyprctl", "dispatch", entry.dispatcher, entry.arg];
		else if (entry.dispatcher !== "" && entry.dispatcher !== "lua")
			cmd = ["hyprctl", "dispatch", entry.dispatcher];
		else {
			// Lua / plain-function binds (toggle_special, resize, copy/paste...):
			// hyprctl cannot run Lua closures, so re-trigger the original
			// chord via wtype and let Hyprland run the real bind.
			var wargs = wtypeArgsForChord(entry.chord);
			if (wargs) {
				var shell = "sleep 0.25; exec wtype";
				for (var i = 0; i < wargs.length; i++)
					shell += " '" + wargs[i].replace(/'/g, "'\\''") + "'";
				// Detached (&): sh exits immediately, menu quits via
				// keysim.onExited, keys land after focus is restored.
				keysim.command = ["sh", "-c", "( " + shell + " ) &"];
				keysim.running = true;
				return;
			}
			return;
		}
		dispatcher.command = cmd;
		dispatcher.running = true;
	}

	Process {
		id: loader
		command: ["keybindings-data", "--json"]
		running: true
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					root.entries = JSON.parse(this.text);
				} catch (e) {
					root.entries = [];
				}
				root.refilter();
			}
		}
	}

	Process {
		id: dispatcher
		onExited: Qt.quit()
	}

	Process {
		id: keysim
		onExited: Qt.quit()
	}

	FloatingWindow {
		id: win
		title: "Keybindings"
		implicitWidth: 800
		implicitHeight: 540
		minimumSize: Qt.size(600, 300)
		maximumSize: Qt.size(1000, 800)
		color: "#0d1117"

		// If the window is closed any other way than Esc/Enter (e.g. SUPER+Q),
		// quit so a stale instance does not block the next launch (-n flag).
		property bool wasShown: false
		onVisibleChanged: {
			if (visible)
				wasShown = true;
			else if (wasShown)
				Qt.quit();
		}

		Rectangle {
			anchors.fill: parent
			color: "#0d1117"
			border.color: "#30363d"
			border.width: 2

			Column {
				anchors.fill: parent
				anchors.margins: 16
				spacing: 12

				TextInput {
					id: searchInput
					width: parent.width
					font.family: "JetBrainsMono Nerd Font Mono"
					font.pixelSize: 18
					color: "#c9d1d9"
					selectionColor: "#58a6ff"
					focus: true
					onTextChanged: root.refilter()
					Keys.onPressed: event => {
						if (event.key === Qt.Key_Down) {
							root.currentIndex = Math.min(root.currentIndex + 1, root.filtered.length - 1);
							event.accepted = true;
						} else if (event.key === Qt.Key_Up) {
							root.currentIndex = Math.max(root.currentIndex - 1, 0);
							event.accepted = true;
						} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
							root.dispatch(root.filtered[root.currentIndex]);
							event.accepted = true;
						} else if (event.key === Qt.Key_Escape) {
							Qt.quit();
							event.accepted = true;
						}
					}
				}

				Rectangle {
					width: parent.width
					height: 1
					color: "#30363d"
				}

				ListView {
					id: list
					width: parent.width
					height: parent.height - searchInput.height - 25
					model: root.filtered
					currentIndex: root.currentIndex
					clip: true
					spacing: 2
					onCountChanged: root.currentIndex = 0

					delegate: Rectangle {
						width: list.width
						height: 34
						color: index === root.currentIndex ? "#21262d" : "transparent"
						border.color: index === root.currentIndex ? "#58a6ff" : "transparent"
						border.width: 1

						Row {
							anchors.fill: parent
							anchors.leftMargin: 12
							anchors.rightMargin: 12
							spacing: 16

							Text {
								width: 300
								anchors.verticalCenter: parent.verticalCenter
								font.family: "JetBrainsMono Nerd Font Mono"
								font.pixelSize: 17
								color: "#58a6ff"
								elide: Text.ElideRight
								text: modelData.chord
							}

							Text {
								anchors.verticalCenter: parent.verticalCenter
								font.family: "JetBrainsMono Nerd Font Mono"
								font.pixelSize: 17
								color: "#c9d1d9"
								elide: Text.ElideRight
								text: modelData.action
							}
						}

						MouseArea {
							anchors.fill: parent
							hoverEnabled: true
							onEntered: root.currentIndex = index
							onClicked: root.dispatch(modelData)
						}
					}
				}
			}
		}
	}
}
