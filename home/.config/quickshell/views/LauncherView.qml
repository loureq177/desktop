import ".."
import "../widgets"
import "../Specials.js" as Specials
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

CenterModal {
	id: window

	panel: "launcher"
	searchIcon: window.mode === "emoji" ? "smile" : window.mode === "keys" ? "keyboard" : "search"
	// Each list says what it is; the apps' search finds the actions too, by
	// name, and draws them like the tiles of Quick actions.
	searchPlaceholder: window.mode === "emoji" ? window.placeholderFor(window.emojis.length, "emoji")
		: window.mode === "keys" ? window.placeholderFor(Keybinds.entries.length, "keys")
		: window.placeholderFor(window.appCount, "apps")
	searchCompleteOnTab: window.isCommandQuery()
	searchLeftRightNavigate: window.mode === "emoji"
	scope: window.mode
	statusText: window.statusText()
	errorText: window.lastError
	showFooter: window.mode === "emoji" || window.lastError !== ""

	readonly property int rowHeight: Theme.rowHeight
	contentHeight: window.filtered.length === 0 ? 72
		: window.mode === "emoji" ? Math.ceil(window.filtered.length / window.gridColumns()) * 76
		: window.filtered.length * window.rowHeight

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

	// "apps" (with the actions, calc and commands), "emoji" or "keys".
	property string mode: "apps"
	property string query: ""
	property var filtered: []
	property int currentIndex: 0
	property string lastError: ""
	property var emojis: []
	property var runCache: []
	property bool runLoaded: false
	readonly property var currentItem: currentIndex >= 0 && currentIndex < filtered.length ? filtered[currentIndex] : null

	// Desktop entries a special workspace stands for are listed as that
	// special instead (below), which opens the app where it lives.
	function listsApp(entry) {
		return !Specials.byDesktopEntry(entry.id);
	}

	readonly property int appCount: (DesktopEntries.applications.values || []).filter(e => window.listsApp(e)).length + specials.length

	// Desktop entries that a bind also starts, for the chord on their tile.
	readonly property var appBinds: ({
		"com.mitchellh.ghostty": "Terminal",
		"firefox": "Browser"
	})

	// The apps that live in a special workspace (the web apps among them),
	// listed with the other apps. The desktop's actions are not here: Quick actions has them
	// all, and the keys list the ones a key does.
	readonly property var specials: {
		// Looked up again once the desktop entries are read.
		void DesktopEntries.applications.values;
		return Specials.list.map(sp => ({
			kind: "special",
			label: sp.app,
			desc: sp.app !== sp.title ? sp.title : sp.desc,
			icon: sp.appIcon.startsWith("icons/") ? sp.appIcon : ((sp.desktop ? DesktopEntries.byId(sp.desktop)?.icon : "") || sp.appIcon),
			lineIcon: sp.icon,
			bind: Specials.bindName(sp),
			keywords: [sp.name, sp.title, sp.keywords].join(" "),
			name: sp.name
		}));
	}

	function chordOf(item) {
		if (!item)
			return "";
		if (item.kind === "key")
			return item.chord;
		if (item.kind === "app")
			return Keybinds.chord(appBinds[item.entry?.id ?? ""] ?? "");
		return Keybinds.chord(item.bind ?? "");
	}

	function spawn(command, workingDirectory) {
		var clean = ["env", "-u", "__EGL_VENDOR_LIBRARY_FILENAMES", "-u", "MALLOC_CONF"].concat(command);
		if (workingDirectory)
			Quickshell.execDetached({ command: clean, workingDirectory: workingDirectory });
		else
			Quickshell.execDetached(clean);
	}

	// A typed command runs where its output can be read, and the window stays
	// once it is done.
	function runInTerminal(commandLine) {
		return ["ghostty", "--wait-after-command=true", "-e", "sh", "-c", commandLine];
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

	onOpened: newMode => {
		var next = newMode === "emoji" || newMode === "keys" ? newMode : "apps";
		if (window.shown && !window.animating && next !== window.mode)
			window.crossfade();
		window.mode = next;
		if (!runLoaded && !runLoader.running)
			runLoader.running = true;
		query = "";
		searchBar.clear();
		refilter();
		searchBar.focusInput();
	}

	function fieldScore(text, ql) {
		var h = (text || "").toLowerCase();
		if (h === "" || ql === "")
			return -1;
		if (h.startsWith(ql))
			return 0;
		var words = h.split(/[^a-z0-9ąćęłńóśźż]+/);
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

	// On appMatchScore's scale: the name, then the description and keywords.
	function specialMatchScore(sp, q) {
		var ql = q.toLowerCase().trim();
		if (ql === "")
			return 0;
		var s = fieldScore(sp.label, ql);
		if (s !== -1)
			return s;
		s = fieldScore(sp.desc, ql);
		if (s !== -1)
			return 3 + s;
		s = fieldScore(sp.keywords, ql);
		return s === -1 ? -1 : 6 + s;
	}

	// The line icon of a key: what it is pressed with.
	function keyIcon(category) {
		if (category === "Mouse" || category === "Bar")
			return "mouse";
		if (category === "Gestures")
			return "hand";
		return "keyboard";
	}

	// The keys list: every key bind and key of the shell (Keybinds), to read.
	readonly property var keyEntries: Keybinds.entries.map(e => ({
		kind: "key",
		label: e.action,
		desc: e.category,
		chord: e.chord,
		lineIcon: keyIcon(e.category)
	}))

	// The keys list matching ql: by what the key does first, then by chord and
	// section, in keyEntries' order among equals (V4's sort is not stable).
	function matchKeys(ql) {
		var scored = [];
		for (var i = 0; i < keyEntries.length; i++) {
			var e = keyEntries[i];
			var s = ql === "" ? 0 : fieldScore(e.label, ql);
			if (s === -1) {
				s = fieldScore(chordOf(e), ql);
				s = s === -1 ? -1 : 4 + s;
			}
			if (s === -1) {
				s = fieldScore(e.desc, ql);
				s = s === -1 ? -1 : 7 + s;
			}
			if (s !== -1)
				scored.push({ score: s, order: i, item: e });
		}
		scored.sort((x, y) => x.score - y.score || x.order - y.order);
		return scored.map(x => x.item);
	}

	function refilter() {
		lastError = "";
		var q = query.trim();

		if (mode === "keys") {
			filtered = matchKeys(q.toLowerCase());
			currentIndex = 0;
			return;
		}

		if (mode === "apps") {
			if (q.startsWith(">")) {
				if (!runLoaded && !runLoader.running)
					runLoader.running = true;
				var cmdQuery = q.substring(1).trim().toLowerCase();
				var cmdResults = [];
				// A bare ">" lists every command there is.
				if (cmdQuery === "") {
					cmdResults = runCache.map(c => ({ kind: "run", label: c }));
				} else {
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
			if (q.startsWith("=")) {
				filtered = calcResult !== null ? [{ kind: "calc", label: calcResult, rawExpr: q }] : [];
				currentIndex = 0;
				return;
			}

			// The apps and the specials, one list: best match first, then by name.
			var scored = [];
			var apps = DesktopEntries.applications.values || [];
			for (var i = 0; i < apps.length; i++) {
				if (!listsApp(apps[i]))
					continue;
				var s = appMatchScore(apps[i], q);
				if (s !== -1)
					scored.push({ score: s, item: { kind: "app", entry: apps[i], label: apps[i].name || apps[i].id } });
			}
			for (var k = 0; k < specials.length; k++) {
				var sk = specialMatchScore(specials[k], q);
				if (sk !== -1)
					scored.push({ score: sk, item: specials[k] });
			}
			scored.sort((a, b) => a.score - b.score || a.item.label.localeCompare(b.item.label));

			var combined = calcResult !== null ? [{ kind: "calc", label: calcResult, rawExpr: q }] : [];
			filtered = combined.concat(scored.map(x => x.item));
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
			spawn(runInTerminal(item.label));
			return true;
		}
		if (item.kind === "emoji") {
			Panels.close("launcher");
			Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/emoji-insert", item.char]);
			return true;
		}
		if (item.kind === "special") {
			Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('" + item.name + "')"]);
			return true;
		}
		// A key is only there to be read.
		if (item.kind === "key")
			return false;
		lastError = "Unknown item type";
		return false;
	}

	function activate() {
		var q = query.trim();
		if (isCommandQuery()) {
			var rawCmd = q.substring(1).trim();
			if (filtered.length === 0 && rawCmd !== "") {
				lastError = "";
				spawn(runInTerminal(rawCmd));
				Panels.close("launcher");
				return;
			}
		}
		if (filtered.length > 0 && currentIndex >= 0 && currentIndex < filtered.length) {
			if (execute(filtered[currentIndex]))
				Panels.close("launcher");
		}
	}


	function gridColumns() {
		if (mode !== "emoji")
			return 1;
		return Math.max(1, Math.floor(contentBox.width / 76));
	}

	function emptyText() {
		if (isCommandQuery())
			return query.trim() === ">" ? "Loading commands..." : "No matching command — Enter runs it anyway";
		if (mode === "emoji") return emojis.length === 0 ? "Loading emojis..." : "No matching emojis";
		if (mode === "keys") return Keybinds.loaded ? "No matching keys or actions" : "Loading keys...";
		if (query.trim().startsWith("="))
			return "Type an expression, like 2+2 or 15% * 80";
		return "Nothing matches";
	}

	function statusText() {
		if (mode === "emoji") {
			if (currentItem)
				return currentItem.char + "  " + String(currentItem.name || "").split(" ").slice(0, 3).join(" ");
			return emojis.length === 0 ? "Loading emojis..." : "No matching emojis";
		}
		return "";
	}

	// The dim text after a row's name.
	function subtitleOf(item) {
		if (item.kind === "app") {
			var e = item.entry;
			return [e.genericName, e.comment, categoryName(e.categories ?? [])].find(d => d && d !== item.label) ?? "";
		}
		if (item.kind === "calc")
			return "Enter copies the result";
		if (item.kind === "run")
			return "";
		return item.desc ?? "";
	}

	// For apps that do not describe themselves: their main freedesktop category.
	readonly property var categoryNames: ({
		"AudioVideo": "Media",
		"Audio": "Audio",
		"Video": "Video",
		"Development": "Development",
		"Education": "Education",
		"Game": "Game",
		"Graphics": "Graphics",
		"Network": "Internet",
		"Office": "Office",
		"Science": "Science",
		"Settings": "Settings",
		"System": "System",
		"Utility": "Utility"
	})

	function categoryName(categories) {
		for (var i = 0; i < categories.length; i++) {
			if (categoryNames[categories[i]])
				return categoryNames[categories[i]];
		}
		return "Application";
	}

	function lineIconOf(item) {
		if (item.kind === "calc")
			return "calculator";
		if (item.kind === "run")
			return "terminal";
		return item.icon || item.entry?.icon ? "" : (item.lineIcon ?? "");
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

	// Keybinds, or the actions' labels (Turn off ...), changed.
	onKeyEntriesChanged: {
		if (window.shown && window.mode === "keys")
			window.refilter();
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

		ListView {
			id: list
			visible: window.mode !== "emoji"
			anchors.fill: parent
			clip: true
			boundsBehavior: Flickable.StopAtBounds
			flickDeceleration: Theme.flickDecel
			maximumFlickVelocity: Theme.maxFlickVel
			model: window.filtered

			WheelScroll {
				flickable: list
			}

			delegate: Rectangle {
				id: row
				required property var modelData
				required property int index
				readonly property bool selected: index === window.currentIndex
				readonly property string chord: window.chordOf(modelData)
				readonly property string subtitle: window.subtitleOf(modelData)

				width: ListView.view.width
				height: window.rowHeight
				radius: Theme.roundingElement
				color: selected ? Theme.selectionBg : "transparent"

				Behavior on color { ColorAnimation { duration: 90 } }

				RowLayout {
					anchors.fill: parent
					anchors.leftMargin: 12
					anchors.rightMargin: 12
					spacing: 12

					Item {
						Layout.preferredWidth: Theme.rowIcon
						Layout.preferredHeight: Theme.rowIcon

						IconImage {
							readonly property string iconName: row.modelData.entry?.icon ?? row.modelData.icon ?? ""
							visible: window.lineIconOf(row.modelData) === ""
							anchors.fill: parent
							implicitSize: Theme.rowIcon
							// One the shell brings (icons/, the web apps'), or the theme's.
							source: iconName.startsWith("icons/") ? "file://" + Quickshell.shellDir + "/" + iconName
								: iconName ? Quickshell.iconPath(iconName, true) : ""
							asynchronous: true
						}

						LineIcon {
							anchors.centerIn: parent
							name: window.lineIconOf(row.modelData)
							size: 22
							color: row.modelData.kind === "calc" ? Theme.accentGreen
								: row.selected ? Theme.accentBlue : Theme.textDim
						}
					}

					Text {
						Layout.maximumWidth: row.width * 0.55
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSize
						font.bold: row.modelData.kind === "calc"
						color: row.modelData.kind === "calc" ? Theme.accentGreen : Theme.textMain
						elide: Text.ElideRight
						text: row.modelData.kind === "calc" ? "= " + row.modelData.label : (row.modelData.label || "")
					}

					Text {
						Layout.fillWidth: true
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSizeSmall + 1
						color: Theme.textDim
						elide: Text.ElideRight
						text: row.subtitle
					}

					// The bind that does the same, as key caps.
					KeyCaps {
						chord: row.chord
						highlighted: row.selected
					}
				}

				HoverSelect {
					enabled: !list.moving
					onSelected: window.currentIndex = row.index
				}

				MouseArea {
					anchors.fill: parent
					onClicked: {
						window.currentIndex = row.index;
						window.activate();
					}
				}
			}
		}

		GridView {
			id: grid
			visible: window.mode === "emoji"
			anchors.top: parent.top
			anchors.bottom: parent.bottom
			anchors.horizontalCenter: parent.horizontalCenter
			width: window.gridColumns() * 76
			clip: true
			boundsBehavior: Flickable.DragAndOvershootBounds
			flickDeceleration: Theme.flickDecel
			maximumFlickVelocity: Theme.maxFlickVel
			cellWidth: 76
			cellHeight: 76
			model: window.mode === "emoji" ? window.filtered : []

			WheelScroll {
				flickable: grid
			}

			delegate: Item {
				id: cell
				required property var modelData
				required property int index
				width: grid.cellWidth
				height: grid.cellHeight

				HoverSelect {
					enabled: !grid.moving
					onSelected: window.currentIndex = cell.index
				}

				Rectangle {
					anchors.fill: parent
					anchors.margins: 3
					color: cell.index === window.currentIndex ? Theme.selectionBg : "transparent"
					radius: Theme.roundingElement

					Text {
						anchors.centerIn: parent
						text: cell.modelData.char || ""
						font.pixelSize: 46
					}
				}

				MouseArea {
					anchors.fill: parent
					onClicked: {
						window.currentIndex = cell.index;
						window.activate();
					}
				}
			}
		}

		Text {
			visible: window.filtered.length === 0
			anchors.centerIn: parent
			font.family: Theme.fontFamily
			font.pixelSize: Theme.fontSizeSmall + 1
			color: Theme.textDim
			text: window.emptyText()
		}
	}
}
