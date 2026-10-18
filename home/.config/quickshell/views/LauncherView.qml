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
	searchIcon: window.mode === "emoji" ? "smile" : window.mode === "actions" ? "keyboard" : "search"
	searchPlaceholder: window.mode === "emoji" ? "Search emoji..." : window.mode === "actions" ? "Search actions and keys..." : "Search apps and actions..."
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
		// Typed into an empty field, the prefix of another list goes there.
		var other = searchQuery === "" ? null : window.scopes.find(s => s.prefix === searchQuery);
		if (window.mode === "apps" && other) {
			window.openScope(other.name);
			return;
		}
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

	// "apps" (with the actions, calc and commands), "emoji" or "actions".
	property string mode: "apps"
	property string query: ""
	property var filtered: []
	property int currentIndex: 0
	property string lastError: ""
	property var emojis: []
	property var runCache: []
	property bool runLoaded: false
	property string pendingPower: ""
	readonly property var currentItem: currentIndex >= 0 && currentIndex < filtered.length ? filtered[currentIndex] : null

	Timer {
		id: powerConfirmTimer
		interval: 4000
		onTriggered: {
			window.pendingPower = "";
		}
	}

	readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

	// Desktop entries that a bind also starts, for the chord on their tile.
	readonly property var appBinds: ({
		"com.mitchellh.ghostty": "Terminal",
		"firefox": "Browser"
	})

	// Everything the desktop does besides starting apps. `bind` is the
	// description of the key bind that does the same (its chord shows on the
	// row, and the actions list files it in that bind's place); without one,
	// `category` is the section of Keybinds it goes in. `run` returns whether
	// the launcher closes afterwards.
	readonly property var toolActions: [
		{ label: "Clipboard history", desc: "Paste something copied before", icon: "edit-paste", bind: "Clipboard history", keywords: "clipboard paste copy schowek historia wklej", run: () => window.openPanel("clipboard") },
		{ label: "Emoji", desc: "Insert an emoji", icon: "accessories-character-map", bind: "Emoji picker", keywords: "emoji emotki smiley picker", run: () => window.openPanel("launcher", "emoji") },
		{ label: "Actions and keys", desc: "Everything the desktop does, with its keys", icon: "preferences-desktop-keyboard-shortcuts", bind: "Actions and keys", keywords: "actions keybindings shortcuts keys help cheatsheet akcje skróty klawisze pomoc", run: () => window.openPanel("launcher", "actions") },
		{ label: "Quick settings", desc: "Volume, brightness, Wi-Fi, Bluetooth", icon: "preferences-system", bind: "Quick settings", keywords: "quick settings actions volume brightness ustawienia głośność jasność dźwięk", run: () => window.openPanel("quicksettings") },
		{ label: "Wi-Fi", desc: "Networks", icon: "network-wireless", category: "System & Tools", keywords: "wifi wi-fi network wireless internet sieć", run: () => window.openPanel("quicksettings", "wifi") },
		{ label: "Bluetooth", desc: "Devices", icon: "bluetooth", category: "System & Tools", keywords: "bluetooth headphones devices słuchawki urządzenia", run: () => window.openPanel("quicksettings", "bluetooth") },
		{ label: "Notifications", desc: "Notification history", icon: "preferences-desktop-notification", bind: "Toggle notification center", keywords: "notifications history powiadomienia", run: () => window.openPanel("notifications") },
		{ label: Notifications.dnd ? "Turn off Do not disturb" : "Do not disturb", desc: "Silence notifications", icon: "notification-disabled", category: "Notifications", keywords: "dnd do not disturb quiet silence nie przeszkadzać cisza", run: () => {
				Notifications.dnd = !Notifications.dnd;
				return true;
			} },
		{ label: "Weather", desc: "Forecast", icon: "indicator-weather", bind: "Weather", keywords: "weather forecast pogoda prognoza", run: () => window.openPanel("weather") },
		{ label: SystemStatus.powerSaveActive ? "Turn off Battery saver" : "Battery saver", desc: "60 Hz, dimmer, fewer effects", icon: "battery", category: "System & Tools", keywords: "battery saver power save 60hz oszczędzanie bateria", run: () => window.script("power-save") },
		{ label: SystemStatus.awakeActive ? "Turn off Keep awake" : "Keep awake", desc: "The screen stays on", icon: "caffeine", category: "System & Tools", keywords: "keep awake caffeine inhibit idle sleep nie usypiaj", run: () => window.script("awake-toggle") },
		{ label: "Next wallpaper", desc: "Change the background", icon: "preferences-desktop-wallpaper", bind: "Next wallpaper", keywords: "wallpaper background tapeta tło", run: () => window.script("wallpaper next") },
		{ label: "Screenshot", desc: "An area or a window", icon: "accessories-screenshot", bind: "Screenshot (region)", keywords: "screenshot capture region window zrzut ekranu", run: () => window.capture("screenshot region") },
		{ label: "Screenshot of the screen", desc: "The whole screen", icon: "applets-screenshooter", bind: "Screenshot (full)", keywords: "screenshot full fullscreen capture zrzut cały ekran", run: () => window.capture("screenshot fullscreen") },
		{ label: SystemStatus.recording ? "Stop recording" : "Record screen", desc: SystemStatus.recording ? "Save the recording" : "An area or a window", icon: "simplescreenrecorder", category: "Capture & OCR", keywords: "record screen video recording nagraj ekran wideo nagrywanie", run: () => window.capture("record-screen") },
		{ label: "Record screen with microphone", desc: "Your voice mixed in", icon: "audio-recorder", hidden: SystemStatus.recording, category: "Capture & OCR", keywords: "record screen microphone mic audio nagraj mikrofon", run: () => window.capture("record-screen --mic") },
		{ label: "Record screen with microphone and camera", desc: "Your voice and a camera overlay", icon: "camera-web", hidden: SystemStatus.recording, category: "Capture & OCR", keywords: "record screen microphone camera webcam kamera nagraj mikrofon", run: () => window.capture("record-screen --mic --cam") },
		{ label: "Color picker", desc: "Copies the hex value", icon: "color-picker", category: "Capture & OCR", keywords: "color colour picker pipette hex kolor pipeta", run: () => window.capture("hyprpicker -a --notify", true) },
		{ label: "Copy text from screen", desc: "Recognises text in an area (OCR)", icon: "ocrfeeder", category: "Capture & OCR", keywords: "ocr text recognize scan tekst rozpoznaj", run: () => window.capture("ocr") },
		{ label: "Dictation", desc: "Type by speaking", icon: "audio-input-microphone", bind: "Dictation", keywords: "dictation voice speech whisper dyktowanie mowa głos", run: () => window.script("dictation") },
		{ label: "System update", desc: "Upgrade the packages", icon: "system-software-update", category: "System & Tools", keywords: "update sysupdate upgrade aktualizacja pacman paru system", run: () => {
				window.spawn(["ghostty", "+new-window", "-e", window.bin + "sysupdate"]);
				return true;
			} },
		{ label: "System cleanup", desc: "Caches, orphaned packages, the trash", icon: "sweeper", category: "System & Tools", keywords: "clean cleanup sysclean cache orphans trash czyszczenie sprzątanie kosz", run: () => {
				window.spawn(["ghostty", "+new-window", "-e", window.bin + "sysclean"]);
				return true;
			} }
	].filter(a => !a.hidden)

	readonly property var specialActions: Specials.list.map(sp => ({
		label: sp.title,
		desc: sp.desc,
		icon: sp.appIcon,
		lineIcon: sp.icon,
		bind: Specials.bindName(sp),
		category: "Special Workspaces",
		keywords: sp.name + " " + sp.keywords,
		run: () => {
			Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('" + sp.name + "')"]);
			return true;
		}
	}))

	readonly property var powerActions: SessionActions.actions.map(a => ({
		label: a.label,
		desc: a.desc,
		icon: a.icon,
		action: a.id,
		verb: a.verb,
		confirm: a.confirm,
		keywords: a.keywords,
		bind: a.id === "lock" ? "Lock system" : "",
		category: "Session"
	}))

	// Kinds the grid tells apart: "app", "action", "power", "calc".
	readonly property var allActions: toolActions.map(a => Object.assign({ kind: "action" }, a))
		.concat(specialActions.map(a => Object.assign({ kind: "action" }, a)))
		.concat(powerActions.map(a => Object.assign({ kind: "power" }, a)))

	function openPanel(name, newMode) {
		Panels.open(name, newMode);
		// Panels replaced the launcher, or reopened it on another mode.
		return false;
	}

	function script(commandLine) {
		spawn(["sh", "-c", window.bin + commandLine]);
		return true;
	}

	// The launcher is gone in the same frame, so it is not in the picture.
	function capture(commandLine, external) {
		Panels.closeInstant();
		spawn(["sh", "-c", "sleep 0.15 && " + (external ? "" : window.bin) + commandLine]);
		return true;
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
		var next = newMode === "emoji" || newMode === "actions" ? newMode : "apps";
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

	function actionMatchScore(a, ql) {
		var s = fieldScore(a.label, ql);
		if (s === -1 && a.keywords) {
			s = fieldScore(a.keywords, ql);
			if (s !== -1)
				s += 1;
		}
		return s;
	}

	// { score, item } of the actions matching ql, best first.
	function matchActions(ql) {
		var scored = [];
		for (var a = 0; a < allActions.length; a++) {
			var sScore = actionMatchScore(allActions[a], ql);
			if (sScore !== -1)
				scored.push({ score: sScore, item: allActions[a] });
		}
		scored.sort((x, y) => x.score - y.score);
		return scored;
	}

	// The line icon of a key: what it is pressed with.
	function keyIcon(category) {
		if (category === "Mouse" || category === "Bar")
			return "mouse";
		if (category === "Gestures")
			return "hand";
		return "keyboard";
	}

	// The actions list: every key bind and key of the shell (Keybinds), the
	// ones an action does too as that action, so Enter runs it, then the
	// actions no key does, each in its section. Under the section, the row
	// says nothing more, as the apps' search does.
	readonly property var actionEntries: {
		var rows = [];
		var bound = {};
		var entries = Keybinds.entries;
		for (var i = 0; i < entries.length; i++) {
			var e = entries[i];
			var same = allActions.find(a => a.bind && a.bind === e.action);
			if (same)
				bound[same.label] = true;
			rows.push(same ? Object.assign({}, same, { desc: e.category })
				: { kind: "key", label: e.action, desc: e.category, chord: e.chord, lineIcon: keyIcon(e.category) });
		}
		rows = rows.concat(allActions.filter(a => !bound[a.label]).map(a => Object.assign({}, a, { desc: a.category ?? "System & Tools" })));
		var order = Keybinds.categoryOrder;
		return rows.map((r, n) => ({ r: r, n: n }))
			.sort((x, y) => order.indexOf(x.r.desc) - order.indexOf(y.r.desc) || x.n - y.n)
			.map(x => x.r);
	}

	// The actions list matching ql: by name first, then by keyword, chord and
	// section, in actionEntries' order among equals (V4's sort is not stable).
	function matchActionEntries(ql) {
		var scored = [];
		for (var i = 0; i < actionEntries.length; i++) {
			var e = actionEntries[i];
			var s = ql === "" ? 0 : fieldScore(e.label, ql);
			if (s === -1 && e.keywords) {
				s = fieldScore(e.keywords, ql);
				s = s === -1 ? -1 : 1 + s;
			}
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
		powerConfirmTimer.stop();
		pendingPower = "";
		var q = query.trim();

		if (mode === "actions") {
			filtered = matchActionEntries(q.toLowerCase());
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

			var matchedActions = q !== "" ? matchActions(q.toLowerCase()) : [];

			var apps = DesktopEntries.applications.values || [];
			var scoredApps = [];
			for (var i = 0; i < apps.length; i++) {
				if (Specials.byDesktopEntry(apps[i].id))
					continue;
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
		if (item.kind === "power") {
			if (item.confirm && window.pendingPower !== item.action) {
				window.pendingPower = item.action;
				powerConfirmTimer.restart();
				return false;
			}
			powerConfirmTimer.stop();
			window.pendingPower = "";
			return SessionActions.run(item.action);
		}
		if (item.kind === "action")
			return item.run();
		// A key no action does is only there to be read.
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
		if (mode === "actions") return Keybinds.loaded ? "No matching actions or keys" : "Loading keys...";
		if (query.trim().startsWith("="))
			return "Type an expression, like 2+2 or 15% * 80";
		return "No matching apps or actions";
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
	onActionEntriesChanged: {
		if (window.shown && window.mode === "actions")
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
				readonly property bool warn: modelData.kind === "power" && window.pendingPower === modelData.action

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
							source: iconName ? Quickshell.iconPath(iconName, true) : ""
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
