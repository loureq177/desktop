import ".."
import "../widgets"
import "../Specials.js" as Specials
import "../Search.js" as Search
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

CenterModal {
	id: window

	panel: "launcher"
	searchIcon: window.mode === "emoji" ? "smile" : window.mode === "keys" ? "keyboard"
		: window.isFileQuery() ? "folder" : window.query.trim().startsWith("=") ? "calculator" : "search"
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
	readonly property int sectionHeight: 34
	contentHeight: window.filtered.length === 0 ? 72
		: window.mode === "emoji" ? Math.ceil(window.filtered.length / window.gridColumns()) * 76
		: window.filtered.length * window.rowHeight + window.sectionCount() * window.sectionHeight

	// The keys list with nothing typed comes in sections, each under its
	// heading instead of with its name after every key. A search mixes them.
	readonly property bool keySections: mode === "keys" && query.trim() === ""

	// The section that starts at index, or "".
	function sectionAt(index) {
		if (!keySections)
			return "";
		var item = filtered[index];
		return index === 0 || filtered[index - 1].desc !== item.desc ? item.desc : "";
	}

	function sectionCount() {
		return keySections ? new Set(filtered.map(e => e.desc)).size : 0;
	}

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

	// "apps" (with the actions, calc, files and commands), "emoji" or "keys".
	property string mode: "apps"
	property string query: ""
	property string lastError: ""
	property var emojis: []
	property var runCache: []
	property bool runLoaded: false
	// The power action waiting for a second Enter, for a few seconds.
	property string pendingPower: ""
	readonly property var currentItem: currentIndex >= 0 && currentIndex < filtered.length ? filtered[currentIndex] : null

	Timer {
		id: powerConfirmTimer
		interval: 4000
		onTriggered: window.pendingPower = ""
	}

	// What the desktop does besides starting apps, found by name in the apps'
	// search, in the shape of Actions.qml; the chord of `bind` shows on the
	// row. The launcher closes after `run`, unless it returns false.
	readonly property var toolActions: [
		{ label: "Clipboard history", desc: "Paste something copied before", lineIcon: "clipboard", bind: "Clipboard history", keywords: "clipboard paste copy schowek historia wklej", run: () => window.openPanel("clipboard") },
		{ label: "Emoji", desc: "Insert an emoji", lineIcon: "smile", bind: "Emoji picker", keywords: "emoji emotki smiley picker", run: () => window.openPanel("launcher", "emoji") },
		{ label: "Keybindings", desc: "Every key and what it does", lineIcon: "keyboard", bind: "Keybindings", keywords: "keys keybindings shortcuts help cheatsheet skróty klawisze pomoc", run: () => window.openPanel("launcher", "keys") },
		{ label: "Quick actions", desc: "Volume, brightness, Wi-Fi, Bluetooth", lineIcon: "layout-grid", bind: "Quick actions", keywords: "quick settings volume brightness ustawienia głośność jasność dźwięk", run: () => window.openPanel("quicksettings") },
		{ label: "Wi-Fi", desc: "Networks", lineIcon: "wifi", keywords: "wifi wi-fi network wireless internet sieć", run: () => window.openPanel("quicksettings", "wifi") },
		{ label: "Bluetooth", desc: "Devices", lineIcon: "bluetooth", keywords: "bluetooth headphones devices słuchawki urządzenia", run: () => window.openPanel("quicksettings", "bluetooth") },
		{ label: "Notifications", desc: "Notification history", lineIcon: "bell", bind: "Toggle notification center", keywords: "notifications history powiadomienia", run: () => window.openPanel("notifications") },
		{ label: Notifications.dnd ? "Turn off Do not disturb" : "Do not disturb", desc: "Silence notifications", lineIcon: "bell-off", keywords: "dnd do not disturb quiet silence nie przeszkadzać cisza", run: () => { Notifications.dnd = !Notifications.dnd; } },
		{ label: "Weather", desc: "Forecast", lineIcon: "cloud-sun", bind: "Weather", keywords: "weather forecast pogoda prognoza", run: () => window.openPanel("weather") },
		{ label: SystemStatus.powerSaveActive ? "Turn off Battery saver" : "Battery saver", desc: "60 Hz, dimmer, fewer effects", lineIcon: "leaf", keywords: "battery saver power save 60hz oszczędzanie bateria", run: () => Actions.togglePowerSave() },
		{ label: SystemStatus.awakeActive ? "Turn off Keep awake" : "Keep awake", desc: "The screen stays on", lineIcon: "coffee", keywords: "keep awake caffeine inhibit idle sleep nie usypiaj", run: () => Actions.toggleAwake() },
		{ label: "Next wallpaper", desc: "Change the background", lineIcon: "image", bind: "Next wallpaper", keywords: "wallpaper background tapeta tło", run: () => Actions.script("wallpaper next") }
	].concat(Actions.captureActions, [
		{ label: "System update", desc: "Upgrade the packages", lineIcon: "package", keywords: "update sysupdate upgrade aktualizacja pacman paru system", run: () => Actions.terminal("sysupdate") },
		{ label: "System cleanup", desc: "Caches, orphaned packages, the trash", lineIcon: "trash", keywords: "clean cleanup sysclean cache orphans trash czyszczenie sprzątanie kosz", run: () => Actions.terminal("sysclean") }
	])

	// Lock, suspend, log out, reboot, power off; the last three run on a
	// second Enter (SessionActions.confirm).
	readonly property var powerActions: SessionActions.actions.map(a => ({
		kind: "power",
		label: a.label,
		desc: a.desc,
		lineIcon: a.lineIcon,
		action: a.id,
		verb: a.verb,
		confirm: a.confirm,
		keywords: a.keywords,
		bind: a.id === "lock" ? "Lock system" : ""
	}))

	readonly property var actions: toolActions.map(a => Object.assign({ kind: "action" }, a)).concat(powerActions)

	function openPanel(name, newMode) {
		Panels.open(name, newMode);
		// Panels replaced the launcher, or reopened it on another mode.
		return false;
	}

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
	// listed with the other apps.
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

	// A typed command runs where its output can be read, and the window stays
	// once it is done.
	function runInTerminal(commandLine) {
		return ["ghostty", "--wait-after-command=true", "-e", "sh", "-c", commandLine];
	}

	function isCommandQuery() {
		return mode === "apps" && query.trim().startsWith(">");
	}

	function isFileQuery() {
		return mode === "apps" && query.trim().startsWith("/");
	}

	// The files found by fd for filesFor (the words typed after "/"): one
	// search at a time, the last words typed next.
	property string filesWanted: ""
	property string filesFor: ""
	property var fileResults: []

	function askFiles(terms) {
		filesWanted = terms.join(" ");
		if (fileProc.running)
			return;
		fileProc.terms = terms;
		fileProc.command = Search.fdCommand(terms, Quickshell.env("HOME"), 400);
		fileProc.running = true;
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

	// The line icon of a key: what it is pressed with.
	function keyIcon(category) {
		if (category === "Mouse" || category === "Bar")
			return "mouse";
		if (category === "Gestures")
			return "hand";
		if (category === "Rules")
			return "sparkles";
		return "keyboard";
	}

	// A key's action with the letter of its key lit where a word starts with
	// it, the last such word first (Show Spotify: the S of Spotify), so the
	// name says the key. Plain text when no word does.
	function mnemonicOf(item) {
		var text = item.label || "";
		var key = item.chord.split(" + ").pop();
		if (item.desc === "Rules" || !/^[A-Z]$/.test(key))
			return "";
		var re = new RegExp("\\b" + key, "gi");
		var at = -1;
		var m;
		while ((m = re.exec(text)) !== null)
			at = m.index;
		if (at === -1)
			return "";
		return text.substring(0, at) + "<font color=\"" + Theme.accentBlue + "\"><b>" + text[at] + "</b></font>" + text.substring(at + 1);
	}

	// The keys list: every key bind and key of the shell (Keybinds), to read.
	readonly property var keyEntries: Keybinds.entries.map(e => ({
		kind: "key",
		label: e.action,
		desc: e.category,
		chord: e.chord,
		lineIcon: keyIcon(e.category)
	}))

	// The keys list matching q: by what the key does first, then by chord and
	// section, in keyEntries' order among equals.
	function matchKeys(q) {
		return Search.rank(keyEntries, e => Search.matchScore([[e.label, 0], [chordOf(e), 4], [e.desc, 7]], q));
	}

	function refilter() {
		lastError = "";
		powerConfirmTimer.stop();
		pendingPower = "";
		var q = query.trim();

		if (mode === "keys") {
			filtered = matchKeys(q);
			currentIndex = 0;
			return;
		}

		if (mode === "apps") {
			if (q.startsWith(">")) {
				if (!runLoaded && !runLoader.running)
					runLoader.running = true;
				// A bare ">" lists every command there is.
				filtered = Search.matchCommands(runCache, q.substring(1), 50).map(c => ({ kind: "run", label: c }));
				currentIndex = 0;
				return;
			}

			var fileTerms = Search.fileTerms(q);
			if (fileTerms !== null) {
				if (fileTerms.length === 0)
					filtered = [];
				else if (filesFor === fileTerms.join(" "))
					filtered = fileResults;
				else {
					// The files of the words before, until fd has these.
					filtered = filtered.filter(it => it.kind === "file");
					askFiles(fileTerms);
				}
				currentIndex = 0;
				return;
			}

			var calcResult = Search.calculate(q);

			// The apps, the specials and the actions, one list: best match
			// first, then by name. The actions only come up when asked for.
			var apps = (DesktopEntries.applications.values || []).filter(e => listsApp(e))
				.map(e => ({ kind: "app", entry: e, label: e.name || e.id }));
			var actionsAsked = q !== "" ? actions : [];
			var matches = Search.rank(apps.concat(specials, actionsAsked),
				it => it.kind === "app" ? Search.appScore(it.entry, q) : Search.itemScore(it, q),
				(a, b) => a.label.localeCompare(b.label));

			var combined = calcResult !== null ? [{ kind: "calc", label: calcResult }] : [];
			filtered = combined.concat(matches);
		} else if (mode === "emoji") {
			var needle = q.toLowerCase();
			filtered = emojis.filter(it => it?.e && String(it.k || "").toLowerCase().includes(needle))
				.map(it => ({ kind: "emoji", char: it.e, name: it.k }));
		}
		currentIndex = 0;
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
				Actions.spawn(["ghostty", "-e"].concat(e.command), e.workingDirectory);
			else
				Actions.spawn(e.command, e.workingDirectory);
			return true;
		}
		if (item.kind === "calc") {
			Quickshell.execDetached(["wl-copy", String(item.label)]);
			return true;
		}
		if (item.kind === "file") {
			Actions.spawn(["xdg-open", item.path]);
			return true;
		}
		if (item.kind === "action")
			return item.run() !== false;
		if (item.kind === "power") {
			if (item.confirm && pendingPower !== item.action) {
				pendingPower = item.action;
				powerConfirmTimer.restart();
				return false;
			}
			powerConfirmTimer.stop();
			pendingPower = "";
			return SessionActions.run(item.action);
		}
		if (item.kind === "run") {
			Actions.spawn(runInTerminal(item.label));
			return true;
		}
		if (item.kind === "emoji") {
			Panels.close("launcher");
			Quickshell.execDetached([Actions.bin + "emoji-insert", item.char]);
			return true;
		}
		if (item.kind === "special") {
			Actions.toggleSpecial(item.name);
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
				Actions.spawn(runInTerminal(rawCmd));
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
		var q = query.trim();
		var terms = Search.fileTerms(q);
		if (terms !== null) {
			if (terms.length === 0)
				return "Type a file or folder name; Enter opens it";
			return filesFor === terms.join(" ") ? "No file or folder called that in ~" : "Searching...";
		}
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
		if (item.kind === "power" && pendingPower === item.action)
			return "Press Enter again to " + item.verb;
		if (item.kind === "calc")
			return "Enter copies the result";
		if (item.kind === "run" || (item.kind === "key" && keySections))
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
		id: fileProc
		property var terms: []
		stdout: StdioCollector {
			onStreamFinished: {
				var home = Quickshell.env("HOME");
				window.filesFor = fileProc.terms.join(" ");
				window.fileResults = Search.rankFiles(String(this.text || "").split("\n"), fileProc.terms, home, 60).map(f => ({
					kind: "file",
					label: f.name,
					desc: f.dir,
					lineIcon: f.icon,
					path: f.path
				}));
				var now = Search.fileTerms(window.query.trim());
				if (window.shown && now !== null && now.join(" ") === window.filesFor)
					window.refilter();
			}
		}
		onExited: {
			if (window.filesWanted !== fileProc.terms.join(" "))
				Qt.callLater(() => window.askFiles(window.filesWanted.split(" ")));
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

		ListView {
			id: list
			visible: window.mode !== "emoji"
			anchors.fill: parent
			clip: true
			model: window.filtered

			WheelScroll {
				flickable: list
			}

			delegate: Item {
				id: entry
				required property var modelData
				required property int index
				readonly property string section: window.sectionAt(index)

				width: ListView.view.width
				height: row.height + (section ? window.sectionHeight : 0)

				Item {
					visible: entry.section !== ""
					width: parent.width
					height: window.sectionHeight

					Rectangle {
						visible: entry.index > 0
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.top: parent.top
						anchors.margins: 12
						anchors.topMargin: 6
						height: 1
						color: Theme.tileBorder
					}

					StyledText {
						anchors.left: parent.left
						anchors.bottom: parent.bottom
						anchors.leftMargin: 12
						anchors.bottomMargin: 4
						text: entry.section.toUpperCase()
						font.pixelSize: Theme.fontSizeTiny
						font.bold: true
						font.letterSpacing: 1
						color: Theme.textMuted
					}
				}

				Rectangle {
					id: row
					readonly property var modelData: entry.modelData
					readonly property int index: entry.index
					readonly property bool selected: index === window.currentIndex
					readonly property string chord: window.chordOf(modelData)
					readonly property string subtitle: window.subtitleOf(modelData)
					readonly property bool warn: modelData.kind === "power" && window.pendingPower === modelData.action

					y: entry.height - height
					width: parent.width
					height: window.rowHeight
					radius: Theme.roundingElement
					color: "transparent"

					SelectionHighlight {
						selected: row.selected
					}

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
									: row.warn ? Theme.warning
									: row.selected ? Theme.accentBlue : Theme.textDim
							}
						}

						StyledText {
							Layout.maximumWidth: row.width * 0.55
							readonly property string mnemonic: row.modelData.kind === "key" ? window.mnemonicOf(row.modelData) : ""
							font.bold: row.modelData.kind === "calc"
							color: row.modelData.kind === "calc" ? Theme.accentGreen : Theme.textMain
							elide: Text.ElideRight
							textFormat: mnemonic ? Text.StyledText : Text.PlainText
							text: mnemonic || (row.modelData.kind === "calc" ? "= " + row.modelData.label : (row.modelData.label || ""))
						}

						StyledText {
							Layout.fillWidth: true
							font.pixelSize: Theme.fontSizeSmall
							color: row.warn ? Theme.warning : Theme.textDim
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
		}

		GridView {
			id: grid
			visible: window.mode === "emoji"
			anchors.top: parent.top
			anchors.bottom: parent.bottom
			anchors.horizontalCenter: parent.horizontalCenter
			width: window.gridColumns() * 76
			clip: true
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
					color: "transparent"
					radius: Theme.roundingElement

					SelectionHighlight {
						selected: cell.index === window.currentIndex
					}

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

		StyledText {
			visible: window.filtered.length === 0
			anchors.centerIn: parent
			font.pixelSize: Theme.fontSizeSmall
			color: Theme.textDim
			text: window.emptyText()
		}
	}
}
