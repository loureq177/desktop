import "../.."
import "../../Search.js" as Search
import Quickshell
import Quickshell.Io
import QtQuick

// The apps, specials and commands by name, and arithmetic; "/" lists only the commands.
LauncherPane {
	id: pane

	readonly property string q: query.trim()
	readonly property bool commandsOnly: q.startsWith("/")

	icon: commandsOnly ? "zap" : q.startsWith("=") ? "calculator" : "search"
	placeholder: "Search " + apps.length + " apps or /actions…"
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

	readonly property var commands: Commands.all.map(c => ({
		label: Commands.label(c),
		subtitle: c.desc,
		lineIcon: c.icon,
		heading: pane.q === "/" ? c.group : "",
		keywords: c.keywords,
		confirm: c.confirm,
		chord: c.bind ? Keybinds.chordFor(c.bind) : "",
		run: c.run
	}))

	onQueryChanged: list.reset()

	ResultList {
		id: list
		anchors.fill: parent

		items: {
			if (pane.commandsOnly)
				return Search.rank(pane.commands, it => Search.itemScore(it, pane.q.substring(1).trim()));
			var calc = Search.calculate(pane.q);
			// The apps and the specials, best match first, then by name; the
			// commands only come up when asked for.
			var matches = Search.rank(pane.q === "" ? pane.apps : pane.apps.concat(pane.commands),
				it => it.entry ? Search.appScore(it.entry, pane.q) : Search.itemScore(it, pane.q),
				(a, b) => a.label.localeCompare(b.label));
			return (calc === null ? [] : [{
				label: "= " + calc,
				subtitle: "Enter copies the result",
				lineIcon: "calculator",
				accent: true,
				run: () => Quickshell.execDetached(["wl-copy", calc])
			}]).concat(matches);
		}

		emptyText: "Nothing matches"
	}
}
