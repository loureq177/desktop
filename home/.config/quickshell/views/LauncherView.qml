import ".."
import "../widgets"
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

CenterModal {
	id: window

	searchTitle: window.modeTitle()
	searchPlaceholder: window.modePlaceholder()
	searchCompleteOnTab: window.mode === "run"
	searchLeftRightNavigate: window.mode === "apps" || window.mode === "emoji"
	statusText: window.statusText()
	errorText: window.lastError
	showFooter: window.mode === "emoji" || window.lastError !== ""

	onSearchQueryChanged: {
		window.query = searchQuery;
		window.refilter();
	}
	onSearchAccepted: window.activate()
	onSearchStepped: delta => window.moveRows(delta, window.gridColumns())
	onSearchSteppedColumn: delta => window.move(delta)
	onSearchCompleted: {
		if (window.mode === "run" && window.filtered.length > 0)
			searchBar.complete(window.filtered[window.currentIndex].label);
	}

	property string mode: "apps"
	property string query: ""
	property var filtered: []
	property int currentIndex: 0
	property string lastError: ""
	property var emojis: []
	property var runCache: []
	property bool runLoaded: false

	readonly property var validModes: ["apps", "run", "emoji", "power"]

	readonly property var powerList: [
		{ label: "lock", icon: "system-lock-screen", kind: "power" },
		{ label: "suspend", icon: "system-suspend", kind: "power" },
		{ label: "reboot", icon: "system-reboot", kind: "power" },
		{ label: "poweroff", icon: "system-shutdown", kind: "power" }
	]

	readonly property var powerCommands: ({
		"lock": ["sh", "-c", "loginctl lock-session"],
		"suspend": ["sh", "-c", "loginctl lock-session && systemctl suspend"],
		"reboot": ["hyprshutdown", "--post-cmd", "systemctl reboot"],
		"poweroff": ["hyprshutdown", "--post-cmd", "systemctl poweroff"]
	})

	readonly property var modeTitles: ({
		"apps": "Apps",
		"run": "Run",
		"emoji": "Emoji",
		"power": "Power"
	})

	readonly property var modePlaceholders: ({
		"apps": "Search applications...",
		"run": "Execute command...",
		"emoji": "Search emojis...",
		"power": "lock / suspend / reboot / poweroff"
	})

	function isMode(m) {
		return validModes.indexOf(m) !== -1;
	}

	function setMode(m) {
		if (m === "drun")
			m = "apps"; // deprecated pre-migration alias
		if (isMode(m)) {
			mode = m;
		}
	}

	function open(newMode) {
		if (newMode !== undefined && newMode !== null && newMode !== "")
			setMode(newMode);
		if (mode === "run" && !runLoaded && !runLoader.running)
			runLoader.running = true;
		query = "";
		searchBar.clear();
		refilter();
		window.shown = true;
		searchBar.focusInput();
	}

	function close() {
		window.shown = false;
	}

	function toggle(newMode) {
		if (window.shown && (newMode === undefined || newMode === null || newMode === "" || newMode === mode))
			close();
		else
			open(newMode);
	}

	// Ranked substring match, name first.
	function fieldScore(text, ql) {
		var h = (text || "").toLowerCase();
		if (h === "" || ql === "")
			return -1;
		if (h.startsWith(ql))
			return 0;
		var words = h.split(/[^a-z0-9]+/);
		for (var i = 0; i < words.length; i++) {
			if (words[i].startsWith(ql))
				return 1;
		}
		if (h.indexOf(ql) !== -1)
			return 2;
		return -1;
	}

	function appMatchScore(e, q) {
		var ql = q.toLowerCase().trim();
		if (ql === "")
			return 0;
		var s = fieldScore(e.name, ql);
		if (s !== -1)
			return s;
		s = fieldScore(e.genericName, ql);
		if (s !== -1)
			return 3 + s;
		s = fieldScore(e.keywords ? e.keywords.join(" ") : "", ql);
		if (s !== -1)
			return 6 + s;
		if (((e.id || "").toLowerCase().indexOf(ql)) !== -1)
			return 9;
		s = fieldScore(e.comment, ql);
		if (s !== -1)
			return 10 + s;
		return -1;
	}

	function refilter() {
		lastError = "";
		var q = query.trim();

		if (mode === "apps") {
			var apps = DesktopEntries.applications.values || [];
			var scored = [];
			for (var i = 0; i < apps.length; i++) {
				var s = appMatchScore(apps[i], q);
				if (q === "" || s !== -1)
					scored.push({ score: s, item: apps[i] });
			}
			scored.sort(function(a, b) {
				if (a.score !== b.score)
					return a.score - b.score;
				return (a.item.name || "").localeCompare(b.item.name || "");
			});
			filtered = scored.map(function(s2) {
				return { kind: "app", entry: s2.item, label: s2.item.name || s2.item.id };
			});
		} else if (mode === "emoji") {
			var needle = q.toLowerCase();
			var out = [];
			for (var j = 0; j < emojis.length; j++) {
				var item = emojis[j];
				if (!item || !item.e)
					continue;
				if (!needle || String(item.k || "").toLowerCase().indexOf(needle) >= 0)
					out.push({ kind: "emoji", char: item.e, name: item.k });
			}
			filtered = out;
		} else if (mode === "power") {
			var ql = q.toLowerCase();
			filtered = powerList.filter(function(p) {
				return q === "" || p.label.toLowerCase().indexOf(ql) !== -1;
			});
		} else if (mode === "run") {
			if (q === "") {
				filtered = [];
			} else {
				var rql = q.toLowerCase();
				var runs = [];
				for (var k = 0; k < runCache.length && runs.length < 50; k++) {
					if (runCache[k].toLowerCase().indexOf(rql) === 0)
						runs.push({ kind: "run", label: runCache[k] });
				}
				for (var m = 0; m < runCache.length && runs.length < 50; m++) {
					var cand = runCache[m].toLowerCase();
					if (cand.indexOf(rql) > 0)
						runs.push({ kind: "run", label: runCache[m] });
				}
				filtered = runs;
			}
		}
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

	function moveRows(delta, cols) {
		move(delta * Math.max(1, cols));
	}

	function execute(item) {
		lastError = "";
		if (!item) {
			lastError = "Nothing selected";
			return false;
		}
		if (item.kind === "app") {
			var e = item.entry;
			if (e.runInTerminal)
				Quickshell.execDetached({ command: ["ghostty", "-e"].concat(e.command), workingDirectory: e.workingDirectory });
			else
				e.execute();
			return true;
		}
		if (item.kind === "run") {
			Quickshell.execDetached(["sh", "-c", item.label]);
			return true;
		}
		if (item.kind === "emoji") {
			close();
			Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/emoji-insert", item.char]);
			return true;
		}
		if (item.kind === "power") {
			var cmd = powerCommands[item.label];
			if (!cmd) {
				lastError = "Unknown power action";
				return false;
			}
			Quickshell.execDetached(cmd);
			return true;
		}
		lastError = "Unknown item type";
		return false;
	}

	function activate() {
		if (mode === "run" && filtered.length === 0 && query.trim() !== "") {
			lastError = "";
			Quickshell.execDetached(["sh", "-c", query.trim()]);
			close();
			return;
		}
		if (execute(filtered[currentIndex]))
			close();
	}

	function gridColumns() {
		return gridColumnCount();
	}

	function desiredCellWidth() {
		return mode === "emoji" ? 76 : 144;
	}

	function gridColumnCount() {
		if (mode !== "apps" && mode !== "emoji")
			return 1;
		var avail = contentBox.width;
		if (!avail || avail <= 0)
			return 1;
		return Math.max(1, Math.floor(avail / desiredCellWidth()));
	}

	function modeTitle() {
		return modeTitles[mode] || "Apps";
	}

	function modePlaceholder() {
		return modePlaceholders[mode] || "";
	}

	function emptyText() {
		if (mode === "run")
			return query.trim() === "" ? "Type a command — Tab completes, Enter runs" : "No match — Enter runs it anyway";
		if (mode === "power") return "No matching power action";
		if (mode === "emoji") return emojis.length === 0 ? "Loading emojis..." : "No matching emojis";
		return "No matching applications";
	}

	function statusText() {
		if (mode === "emoji") {
			if (filtered.length > 0 && currentIndex >= 0 && currentIndex < filtered.length) {
				var sel = filtered[currentIndex];
				return sel.char + "  " + String(sel.name || "").split(" ").slice(0, 3).join(" ");
			}
			return emojis.length === 0 ? "Loading emojis..." : "No matching emojis";
		}
		return "";
	}

	onCurrentIndexChanged: {
		if (grid.visible)
			grid.positionViewAtIndex(currentIndex, GridView.Contain);
		else
			list.positionViewAtIndex(currentIndex, ListView.Contain);
	}

	FileView {
		path: Quickshell.shellDir + "/emojis.json"
		onLoaded: {
			try {
				var parsed = JSON.parse(text());
				window.emojis = Array.isArray(parsed) ? parsed : [];
			} catch (e) {
				window.emojis = [];
			}
			if (window.mode === "emoji")
				window.refilter();
		}
	}

	Connections {
		target: DesktopEntries.applications
		function onValuesChanged() {
			if (window.mode === "apps")
				window.refilter();
		}
	}

	Process {
		id: runLoader
		running: false
		command: ["bash", "-c", "compgen -c | sort -u"]
		stdout: StdioCollector {
			onStreamFinished: {
				var clean = [];
				var lines = String(this.text || "").split("\n");
				for (var i = 0; i < lines.length; i++) {
					var line = lines[i].trim();
					if (line !== "")
						clean.push(line);
				}
				window.runCache = clean;
				window.runLoaded = true;
				if (window.mode === "run" && window.shown)
					window.refilter();
			}
		}
	}

	// Main body slot for CenterModal
	Item {
		id: contentBox
		anchors.fill: parent

		GridView {
			id: grid
			visible: window.mode === "apps" || window.mode === "emoji"
			anchors.top: parent.top
			anchors.bottom: parent.bottom
			anchors.horizontalCenter: parent.horizontalCenter
			width: window.gridColumnCount() * window.desiredCellWidth()
			clip: true
			flickDeceleration: 600
			maximumFlickVelocity: 4000
			cellWidth: window.desiredCellWidth()
			cellHeight: window.mode === "emoji" ? 76 : 132
			model: window.filtered

			delegate: Item {
				width: grid.cellWidth
				height: grid.cellHeight

				Rectangle {
					anchors.fill: parent
					anchors.margins: window.mode === "emoji" ? 3 : 6
					color: index === window.currentIndex ? Theme.selectionBg : "transparent"
					border.color: index === window.currentIndex ? Theme.selectionBorder : "transparent"
					border.width: 1
					radius: Theme.roundingElement

					Behavior on color { ColorAnimation { duration: 100 } }

					// App icon & title for apps mode
					ColumnLayout {
						visible: modelData.kind === "app"
						anchors.fill: parent
						anchors.margins: Theme.paddingItem
						spacing: 4

						IconImage {
							Layout.alignment: Qt.AlignHCenter
							implicitSize: 48
							source: modelData.entry && modelData.entry.icon ? Quickshell.iconPath(modelData.entry.icon, true) : ""
							asynchronous: true
						}

						Text {
							Layout.fillWidth: true
							Layout.fillHeight: true
							horizontalAlignment: Text.AlignHCenter
							verticalAlignment: Text.AlignVCenter
							wrapMode: Text.Wrap
							maximumLineCount: 2
							elide: Text.ElideRight
							font.family: Theme.fontMono
							font.pointSize: Theme.fontSizeGrid
							color: index === window.currentIndex ? Theme.accentBlue : Theme.textMain
							text: modelData.label || ""
						}
					}

					// Emoji glyph for emoji mode
					Text {
						visible: modelData.kind === "emoji"
						anchors.centerIn: parent
						text: modelData.char || ""
						font.pixelSize: 46
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

		ListView {
			id: list
			visible: window.mode === "run" || window.mode === "power"
			anchors.fill: parent
			clip: true
			flickDeceleration: 600
			maximumFlickVelocity: 4000
			spacing: 4
			model: window.filtered
			delegate: Rectangle {
				width: list.width
				height: 52
				color: index === window.currentIndex ? Theme.selectionBg : "transparent"
				border.color: index === window.currentIndex ? Theme.selectionBorder : "transparent"
				border.width: 1
				radius: Theme.roundingElement

				Behavior on color { ColorAnimation { duration: 100 } }

				RowLayout {
					anchors.fill: parent
					anchors.leftMargin: 14
					anchors.rightMargin: 14
					spacing: 14

					IconImage {
						visible: modelData.kind === "power"
						Layout.alignment: Qt.AlignVCenter
						implicitSize: 24
						source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
						asynchronous: true
					}

					Text {
						Layout.fillWidth: true
						Layout.alignment: Qt.AlignVCenter
						font.family: Theme.fontMono
						font.pointSize: Theme.fontSizeBar
						color: index === window.currentIndex ? Theme.accentBlue : Theme.textMain
						elide: Text.ElideRight
						text: modelData.label || ""
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
			visible: window.filtered.length === 0
			anchors.centerIn: parent
			font.family: Theme.fontMono
			font.pointSize: Theme.fontSizeBar
			color: Theme.textDim
			text: window.emptyText()
		}
	}
}
