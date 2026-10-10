import ".."
import "../widgets"
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

CenterModal {
	id: window

	searchTitle: window.mode === "apps" ? "" : window.modeTitle()
	searchPlaceholder: window.modePlaceholder()
	searchCompleteOnTab: window.isCommandQuery()
	searchLeftRightNavigate: (window.mode === "apps" && !window.isCommandQuery()) || window.mode === "emoji"
	searchScopeHints: window.mode === "apps"
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
		if (window.isCommandQuery() && window.filtered.length > 0 && window.currentIndex < window.filtered.length) {
			var compLabel = window.filtered[window.currentIndex].label;
			searchBar.complete("> " + compLabel);
		}
	}

	property string mode: "apps"
	property string query: ""
	property var filtered: []
	property int currentIndex: 0
	property string lastError: ""
	property var emojis: []
	property var runCache: []
	property bool runLoaded: false
	property string pendingPower: ""

	Timer {
		id: powerConfirmTimer
		interval: 4000
		onTriggered: {
			window.pendingPower = "";
			if (window.lastError.indexOf("Press Enter again") === 0)
				window.lastError = "";
		}
	}

	readonly property var validModes: ["apps", "emoji", "power"]

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

	readonly property var systemActions: [
		{ label: "Lock session", icon: "system-lock-screen", kind: "power", action: "lock", keywords: "lock zablokuj ekran lockscreen" },
		{ label: "Suspend", icon: "system-suspend", kind: "power", action: "suspend", keywords: "suspend sleep uspij uśpij drzemka" },
		{ label: "Reboot", icon: "system-reboot", kind: "power", action: "reboot", keywords: "reboot restart uruchom ponownie zrestartuj" },
		{ label: "Power off", icon: "system-shutdown", kind: "power", action: "poweroff", keywords: "poweroff shutdown wylacz wyłącz power exit wyloguj" },
		{ label: "System update", icon: "system-software-update", kind: "action", cmd: ["ghostty", "+new-window", "-e", Quickshell.env("HOME") + "/.local/bin/sysupdate"], keywords: "update sysupdate aktualizacja pacman paru system" }
	]

	readonly property var modeTitles: ({
		"apps": "",
		"emoji": "Emoji",
		"power": "Power"
	})

	readonly property var modePlaceholders: ({
		"apps": "Search...",
		"emoji": "Search emoji...",
		"power": "lock / suspend / reboot / poweroff"
	})

	function spawn(command, workingDirectory) {
		var clean = ["env", "-u", "__EGL_VENDOR_LIBRARY_FILENAMES", "-u", "MALLOC_CONF"].concat(command);
		if (workingDirectory)
			Quickshell.execDetached({ command: clean, workingDirectory: workingDirectory });
		else
			Quickshell.execDetached(clean);
	}

	function isMode(m) {
		return validModes.indexOf(m) !== -1;
	}

	function setMode(m) {
		if (isMode(m)) {
			mode = m;
		}
	}

	function isCommandQuery() {
		return mode === "apps" && query.trim().startsWith(">");
	}

	function tryCalculate(raw) {
		var s = (raw || "").trim();
		if (s.startsWith("="))
			s = s.substring(1).trim();
		if (s === "")
			return null;
		if (!/^[0-9+\-*/^().,% xX÷]+$/.test(s))
			return null;
		s = s.replace(/(\d),(\d)/g, "$1.$2");
		if (s.indexOf(",") !== -1)
			return null;
		s = s.replace(/x|X/g, "*").replace(/÷/g, "/");
		if (!/[+\-*/^%]/.test(s))
			return null;
		s = s.replace(/\^/g, "**");
		s = s.replace(/(\d+(?:\.\d+)?)%/g, "($1/100)");

		try {
			var fn = new Function("return (" + s + ")");
			var res = fn();
			if (typeof res === "number" && isFinite(res) && !isNaN(res)) {
				var rounded = Math.round(res * 1e10) / 1e10;
				return String(rounded);
			}
		} catch (e) {
			return null;
		}
		return null;
	}

	function open(newMode) {
		if (newMode !== undefined && newMode !== null && newMode !== "")
			setMode(newMode);
		if (!runLoaded && !runLoader.running)
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
		powerConfirmTimer.stop();
		pendingPower = "";
		var q = query.trim();

		if (mode === "apps") {
			if (q.startsWith(">")) {
				if (!runLoaded && !runLoader.running)
					runLoader.running = true;
				var cmdQuery = q.substring(1).trim().toLowerCase();
				var cmdResults = [];
				if (cmdQuery !== "") {
					cmdResults.push({ kind: "run", label: q.substring(1).trim(), isDirect: true });
					for (var k = 0; k < runCache.length && cmdResults.length < 50; k++) {
						var cand = runCache[k].toLowerCase();
						if (cand !== cmdQuery && cand.indexOf(cmdQuery) === 0)
							cmdResults.push({ kind: "run", label: runCache[k] });
					}
					for (var m = 0; m < runCache.length && cmdResults.length < 50; m++) {
						var cand2 = runCache[m].toLowerCase();
						if (cand2.indexOf(cmdQuery) > 0)
							cmdResults.push({ kind: "run", label: runCache[m] });
					}
				}
				filtered = cmdResults;
				currentIndex = 0;
				return;
			}

			var calcResult = tryCalculate(q);

			var matchedActions = [];
			if (q !== "") {
				var ql = q.toLowerCase();
				for (var a = 0; a < systemActions.length; a++) {
					var act = systemActions[a];
					var sScore = fieldScore(act.label, ql);
					if (sScore === -1 && act.keywords)
						sScore = fieldScore(act.keywords, ql);
					if (sScore !== -1)
						matchedActions.push({ score: sScore, item: act });
				}
				matchedActions.sort(function(x, y) { return x.score - y.score; });
			}

			var apps = DesktopEntries.applications.values || [];
			var scoredApps = [];
			for (var i = 0; i < apps.length; i++) {
				var s = appMatchScore(apps[i], q);
				if (q === "" || s !== -1)
					scoredApps.push({ score: s, item: apps[i] });
			}
			scoredApps.sort(function(a, b) {
				if (a.score !== b.score)
					return a.score - b.score;
				return (a.item.name || "").localeCompare(b.item.name || "");
			});

			var appItems = scoredApps.map(function(s2) {
				return { kind: "app", entry: s2.item, label: s2.item.name || s2.item.id };
			});

			var actionItems = matchedActions.map(function(ma) {
				return ma.item;
			});

			var combined = [];
			if (calcResult !== null) {
				combined.push({ kind: "calc", label: calcResult, rawExpr: q });
			}

			if (actionItems.length > 0 && matchedActions[0].score === 0 && (scoredApps.length === 0 || scoredApps[0].score > 0)) {
				combined = combined.concat(actionItems);
				combined = combined.concat(appItems);
			} else {
				combined = combined.concat(appItems);
				combined = combined.concat(actionItems);
			}

			filtered = combined;
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
			var pql = q.toLowerCase();
			filtered = powerList.filter(function(p) {
				return q === "" || p.label.toLowerCase().indexOf(pql) !== -1;
			});
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
				spawn(["ghostty", "-e"].concat(e.command), e.workingDirectory);
			else
				spawn(e.command, e.workingDirectory);
			return true;
		}
		if (item.kind === "calc") {
			Quickshell.execDetached(["wl-copy", String(item.label)]);
			return true;
		}
		if (item.kind === "run") {
			spawn(["sh", "-c", item.label]);
			return true;
		}
		if (item.kind === "emoji") {
			close();
			Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/emoji-insert", item.char]);
			return true;
		}
		if (item.kind === "power") {
			var pKey = item.action || item.label;
			if ((pKey === "reboot" || pKey === "poweroff") && window.pendingPower !== pKey) {
				window.pendingPower = pKey;
				window.lastError = "Press Enter again to confirm " + pKey;
				powerConfirmTimer.restart();
				return false;
			}
			powerConfirmTimer.stop();
			window.pendingPower = "";
			var cmd = powerCommands[pKey];
			if (!cmd) {
				lastError = "Unknown power action";
				return false;
			}
			spawn(cmd);
			return true;
		}
		if (item.kind === "action") {
			if (item.cmd) {
				spawn(item.cmd);
				return true;
			}
			return false;
		}
		lastError = "Unknown item type";
		return false;
	}

	function activate() {
		var q = query.trim();
		if (isCommandQuery()) {
			var rawCmd = q.substring(1).trim();
			if (filtered.length === 0 && rawCmd !== "") {
				lastError = "";
				spawn(["sh", "-c", rawCmd]);
				close();
				return;
			}
		}
		if (filtered.length > 0 && currentIndex >= 0 && currentIndex < filtered.length) {
			if (execute(filtered[currentIndex]))
				close();
		}
	}

	function gridColumns() {
		if (isCommandQuery())
			return 1;
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
		return modeTitles[mode] || "";
	}

	function modePlaceholder() {
		return modePlaceholders[mode] || "";
	}

	function emptyText() {
		if (isCommandQuery())
			return query.trim() === "" ? "Type a command — Enter runs" : "No matching command — Enter runs it anyway";
		if (mode === "power") return "No matching power action";
		if (mode === "emoji") return emojis.length === 0 ? "Loading emojis..." : "No matching emojis";
		return "No matching applications or actions";
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

	onVisibleChanged: {
		if (!visible)
			filtered = [];
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
			if (window.shown && window.mode === "apps")
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
				if (window.isCommandQuery() && window.shown)
					window.refilter();
			}
		}
	}

	Item {
		id: contentBox
		anchors.fill: parent

		GridView {
			id: grid
			visible: (window.mode === "apps" && !window.isCommandQuery()) || window.mode === "emoji"
			anchors.top: parent.top
			anchors.bottom: parent.bottom
			anchors.horizontalCenter: parent.horizontalCenter
			width: window.gridColumnCount() * window.desiredCellWidth()
			clip: true
			boundsBehavior: Flickable.DragAndOvershootBounds
			flickDeceleration: Theme.flickDecel
			maximumFlickVelocity: Theme.maxFlickVel
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

					ColumnLayout {
						visible: modelData.kind === "power" || modelData.kind === "action"
						anchors.fill: parent
						anchors.margins: Theme.paddingItem
						spacing: 4

						IconImage {
							Layout.alignment: Qt.AlignHCenter
							implicitSize: 48
							source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
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

					ColumnLayout {
						visible: modelData.kind === "calc"
						anchors.fill: parent
						anchors.margins: Theme.paddingItem
						spacing: 4

						Text {
							Layout.alignment: Qt.AlignHCenter
							text: "󰪚"
							font.family: Theme.fontFamily
							font.pixelSize: 40
							color: index === window.currentIndex ? Theme.accentGreen : Theme.accentBlue
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
							font.pointSize: Theme.fontSizeGrid + 1
							font.bold: true
							color: index === window.currentIndex ? Theme.accentGreen : Theme.textMain
							text: "= " + (modelData.label || "")
						}
					}

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
					onEntered: {
						if (!grid.moving && !grid.flicking)
							window.currentIndex = index;
					}
					onClicked: {
						window.currentIndex = index;
						window.activate();
					}
				}
			}
		}

		ListView {
			id: list
			visible: window.mode === "power" || (window.mode === "apps" && window.isCommandQuery())
			anchors.fill: parent
			clip: true
			boundsBehavior: Flickable.DragAndOvershootBounds
			flickDeceleration: Theme.flickDecel
			maximumFlickVelocity: Theme.maxFlickVel
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

					Text {
						visible: modelData.kind === "run"
						Layout.alignment: Qt.AlignVCenter
						text: "󰞷"
						font.family: Theme.fontFamily
						font.pixelSize: 20
						color: Theme.accentPurple
					}

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

					Rectangle {
						visible: modelData.kind === "run"
						Layout.alignment: Qt.AlignVCenter
						implicitWidth: badgeText.implicitWidth + 10
						implicitHeight: 22
						radius: Theme.roundingSubtle
						color: Theme.bgCard
						border.color: Theme.border
						border.width: 1

						Text {
							id: badgeText
							anchors.centerIn: parent
							text: "Terminal"
							font.family: Theme.fontMono
							font.pointSize: Theme.fontSizeSmall - 2
							color: Theme.textDim
						}
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
			visible: window.filtered.length === 0
			anchors.centerIn: parent
			font.family: Theme.fontMono
			font.pointSize: Theme.fontSizeBar
			color: Theme.textDim
			text: window.emptyText()
		}
	}
}
