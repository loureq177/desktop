import "../.."
import "../../Search.js" as Search
import Quickshell
import Quickshell.Io
import QtQuick

// The apps, specials and commands by name, then settings and files; arithmetic. "/" lists only
// the commands.
LauncherPane {
	id: pane

	readonly property string q: query.trim()
	readonly property bool commandsOnly: q.startsWith("/")
	// Where a setting found here is edited.
	property var settingsPane: null

	icon: commandsOnly ? "zap" : q.startsWith("=") ? "calculator" : "search"
	placeholder: "Search apps, settings, files or /commands…"
	preferredHeight: list.preferredHeight

	function step(delta: int, repeat: bool): void {
		list.step(delta, repeat);
	}

	function activate(): void {
		list.activate();
	}

	// Today, for the calendar's icon: set as the launcher opens.
	property int day: new Date().getDate()

	function opened(): void {
		day = new Date().getDate();
		list.rewind();
	}

	// The icon with today's date in its <text id="day">.
	function dated(icon: string): string {
		if (icon !== "icons/google-calendar.svg" || calendarIcon.text() === "")
			return icon;
		return "data:image/svg+xml;utf8," + encodeURIComponent(calendarIcon.text().replace(/(id="day"[^>]*>)\d+</, "$1" + day + "<"));
	}

	FileView {
		id: calendarIcon
		path: Quickshell.shellDir + "/icons/google-calendar.svg"
		blockLoading: true
		printErrors: false
	}

	// Desktop entries a special workspace stands for are listed as that special
	// instead, which opens the app where it lives.
	readonly property var apps: (DesktopEntries.applications.values ?? []).filter(e => !Specials.byDesktopEntry(e.id)).map(e => {
		var label = e.name || e.id;
		return {
			label: label,
			subtitle: [e.genericName, e.comment].find(d => d && d !== label) ?? "",
			icon: e.icon,
			entry: e,
			run: () => Hypr.exec(Commands.entryCommand(e), e.workingDirectory)
		};
	}).concat(Specials.list.map(sp => ({
		label: sp.app,
		subtitle: sp.app !== sp.title ? sp.title : sp.desc,
		icon: sp.appIcon.startsWith("icons/") ? pane.dated(sp.appIcon) : (sp.desktop ? DesktopEntries.byId(sp.desktop)?.icon : "") || sp.appIcon,
		lineIcon: sp.icon,
		keywords: [sp.name, sp.title, sp.keywords].join(" "),
		run: () => Hypr.toggleSpecial(sp.name)
	})))

	// Not per key: the headings come in rows, for "/" alone.
	readonly property var commands: Commands.all.map(c => ({
		label: Commands.label(c),
		subtitle: c.desc,
		lineIcon: c.icon,
		group: c.group,
		keywords: c.keywords,
		confirm: c.confirm,
		chord: c.bind ? Keybinds.chordFor(c.bind) : "",
		run: c.query ? () => {
			pane.queryRequested(c.query);
			return false;
		} : c.run
	}))

	// "timer 25", "/timer 1h 30", "timer 90s": seconds, or 0. A number with no unit is minutes.
	function timerSeconds(): int {
		var m = /^\/?timer\s+(.+)$/i.exec(q);
		var spec = m ? m[1].toLowerCase().replace(/\s+/g, "") : "";
		if (/\d$/.test(spec))
			spec += "m";
		if (!/^(\d+(h|min|m|s))+$/.test(spec))
			return 0;
		var secs = 0, unit = { h: 3600, min: 60, m: 60, s: 1 }, re = /(\d+)(h|min|m|s)/g, part;
		while ((part = re.exec(spec)) !== null)
			secs += parseInt(part[1]) * unit[part[2]];
		return secs;
	}

	function spoken(secs: int): string {
		var h = Math.floor(secs / 3600), m = Math.floor(secs / 60) % 60, s = secs % 60;
		return [h ? h + " h" : "", m ? m + " min" : "", s ? s + " s" : ""].filter(x => x).join(" ");
	}

	// A bool flips here; the rest opens in the settings, Esc back to their list.
	readonly property var settingRows: {
		if (q.length < 2 || commandsOnly || !settingsPane)
			return [];
		var pages = Settings.pages.filter(p => Search.matchScore([[p.label, 0], [p.keywords ?? "", 6]], q) !== -1).map(p => ({
			label: p.label,
			subtitle: "Settings",
			lineIcon: p.icon,
			heading: "settings",
			run: () => {
				Panels.open("launcher", "settings");
				pane.settingsPane.openSection(p.key);
				return false;
			}
		}));
		return pages.concat(Search.rank(Settings.entries, e => Search.settingScore(e, q, false)).slice(0, 4).map(e => ({
			label: e.label,
			subtitle: e.group,
			lineIcon: e.icon,
			heading: "settings",
			setting: e,
			run: () => {
				if (e.kind === "bool") {
					Settings.set(e, !e.value);
					return false;
				}
				Panels.open("launcher", "settings");
				pane.settingsPane.edit(e);
				return false;
			}
		})));
	}

	FileSearch {
		id: files
		query: !pane.commandsOnly && pane.q.length >= 2 && Search.calculate(pane.q) === null ? pane.q : ""
	}

	// Files come in after the keypress: the row picked stays.
	onRowsChanged: {
		var index = list.currentIndex;
		list.items = rows;
		list.currentIndex = Math.max(0, Math.min(index, list.count - 1));
	}
	Component.onCompleted: list.items = rows
	onQueryChanged: list.reset()

	ResultList {
		id: list
		anchors.fill: parent
		emptyText: files.searching ? "" : "Nothing matches"
	}

	readonly property var rows: {
		var secs = pane.timerSeconds();
		var timer = secs > 0 ? [{
			label: "Timer " + pane.spoken(secs),
			subtitle: "Enter starts it" + (Modes.timerLeft > 0 ? " instead of the " + Modes.timerText(Modes.timerLeft) + " left" : ""),
			lineIcon: "timer",
			accent: true,
			run: () => Commands.script("timer " + secs + "s")
		}] : [];
		if (pane.q === "/")
			return pane.commands.map(c => Object.assign({ heading: c.group }, c));
		if (pane.commandsOnly)
			return timer.concat(Search.rank(pane.commands, it => Search.itemScore(it, pane.q.substring(1).trim())));
		var calc = Search.calculate(pane.q);
		// The apps and the specials, best match first, then by name; the
		// commands only come up when asked for.
		var matches = Search.rank(pane.q === "" ? pane.apps : pane.apps.concat(pane.commands),
			it => it.entry ? Search.appScore(it.entry, pane.q) : Search.itemScore(it, pane.q),
			(a, b) => a.label.localeCompare(b.label));
		return timer.concat(calc === null ? [] : [{
			label: "= " + calc,
			subtitle: "Enter copies the result",
			lineIcon: "calculator",
			accent: true,
			run: () => Quickshell.execDetached(["wl-copy", calc])
		}]).concat(matches, pane.settingRows, files.items);
	}
}
