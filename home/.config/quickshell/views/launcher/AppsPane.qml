import "../.."
import "../../Specials.js" as Specials
import "../../Search.js" as Search
import Quickshell
import QtQuick

// The launcher's first list: the apps, the specials and the commands by name,
// and arithmetic ("2+2").
LauncherPane {
	id: pane

	readonly property string q: query.trim()

	icon: q.startsWith("=") ? "calculator" : "search"
	placeholder: "Search " + apps.length + " apps..."
	preferredHeight: list.preferredHeight

	function step(delta: int): void {
		list.step(delta);
	}

	function activate(): void {
		list.activate();
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
			run: () => Hypr.exec(e.runInTerminal ? ["ghostty", "-e"].concat(e.command) : e.command, e.workingDirectory)
		};
	}).concat(Specials.list.map(sp => ({
		label: sp.app,
		subtitle: sp.app !== sp.title ? sp.title : sp.desc,
		icon: sp.appIcon.startsWith("icons/") ? sp.appIcon : (sp.desktop ? DesktopEntries.byId(sp.desktop)?.icon : "") || sp.appIcon,
		lineIcon: sp.icon,
		keywords: [sp.name, sp.title, sp.keywords].join(" "),
		run: () => Hypr.toggleSpecial(sp.name)
	})))

	readonly property var commands: Commands.all.map(c => ({
		label: Commands.label(c),
		subtitle: c.desc,
		lineIcon: c.icon,
		keywords: c.keywords,
		confirm: c.confirm,
		run: c.run
	}))

	onQueryChanged: list.reset()

	ResultList {
		id: list
		anchors.fill: parent

		items: {
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
