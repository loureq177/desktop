import "../.."
import "../../Specials.js" as Specials
import "../../Search.js" as Search
import Quickshell
import Quickshell.Io
import QtQuick

// The launcher's first list: the apps, the specials and the commands by name,
// arithmetic ("2+2"), the files in ~ ("/" and a name) and every command on
// the PATH (">", run in a terminal).
ResultList {
	id: pane

	property string query: ""
	readonly property string q: query.trim()
	readonly property bool commandQuery: q.startsWith(">")
	readonly property var fileTerms: Search.fileTerms(q)

	readonly property string icon: fileTerms !== null ? "folder" : q.startsWith("=") ? "calculator" : "search"
	readonly property string placeholder: "Search " + apps.length + " apps..."
	readonly property bool completeOnTab: commandQuery

	// Desktop entries that a bind also starts, for the chord on their row.
	readonly property var appBinds: ({
		"com.mitchellh.ghostty": "Terminal",
		"firefox": "Browser"
	})

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

	// Desktop entries a special workspace stands for are listed as that special
	// instead, which opens the app where it lives.
	readonly property var apps: (DesktopEntries.applications.values ?? []).filter(e => !Specials.byDesktopEntry(e.id)).map(e => {
		var label = e.name || e.id;
		var category = (e.categories ?? []).map(c => categoryNames[c]).find(c => c) ?? "Application";
		return {
			label: label,
			subtitle: [e.genericName, e.comment, category].find(d => d && d !== label) ?? "",
			icon: e.icon,
			chord: Keybinds.chord(appBinds[e.id] ?? ""),
			entry: e,
			run: () => Commands.spawn(e.runInTerminal ? ["ghostty", "-e"].concat(e.command) : e.command, e.workingDirectory)
		};
	}).concat(Specials.list.map(sp => ({
		label: sp.app,
		subtitle: sp.app !== sp.title ? sp.title : sp.desc,
		icon: sp.appIcon.startsWith("icons/") ? sp.appIcon : (sp.desktop ? DesktopEntries.byId(sp.desktop)?.icon : "") || sp.appIcon,
		lineIcon: sp.icon,
		chord: Keybinds.chord(sp.title),
		keywords: [sp.name, sp.title, sp.keywords].join(" "),
		run: () => Commands.toggleSpecial(sp.name)
	})))

	readonly property var commands: Commands.all.map(c => ({
		label: Commands.label(c),
		subtitle: c.desc,
		lineIcon: c.icon,
		chord: Keybinds.chord(c.bind ?? ""),
		keywords: c.keywords,
		confirm: c.confirm,
		run: c.run
	}))

	// The files fd found for `filesFor`: one search at a time, the words typed
	// last next.
	property string filesFor: ""
	property var files: []
	// Every command on the PATH, read on the first ">".
	property var pathCommands: []

	onFileTermsChanged: {
		if (fileTerms !== null && fileTerms.length > 0 && !fileProc.running)
			fileProc.search(fileTerms);
	}
	onCommandQueryChanged: {
		if (commandQuery && pathCommands.length === 0)
			pathProc.running = true;
	}
	onQueryChanged: reset()

	items: {
		if (commandQuery)
			return Search.matchCommands(pathCommands, q.substring(1), 50).map(c => ({
				label: c,
				lineIcon: "terminal",
				run: () => Commands.spawn(["ghostty", "--wait-after-command=true", "-e", "sh", "-c", c])
			}));
		if (fileTerms !== null)
			return fileTerms.length === 0 ? [] : files;
		var calc = Search.calculate(q);
		// The apps and the specials, best match first, then by name; the
		// commands only come up when asked for.
		var matches = Search.rank(q === "" ? apps : apps.concat(commands),
			it => it.entry ? Search.appScore(it.entry, q) : Search.itemScore(it, q),
			(a, b) => a.label.localeCompare(b.label));
		return (calc === null ? [] : [{
			label: "= " + calc,
			subtitle: "Enter copies the result",
			lineIcon: "calculator",
			accent: true,
			run: () => Quickshell.execDetached(["wl-copy", calc])
		}]).concat(matches);
	}

	emptyText: {
		if (commandQuery)
			return "Loading commands...";
		if (fileTerms === null)
			return "Nothing matches";
		if (fileTerms.length === 0)
			return "Type a file or folder name; Enter opens it";
		return filesFor === fileTerms.join(" ") ? "No file or folder called that in ~" : "Searching...";
	}

	function complete(): string {
		return currentIndex < items.length ? "> " + items[currentIndex].label : "";
	}

	Process {
		id: fileProc

		property var terms: []

		function search(words: var): void {
			terms = words;
			command = Search.fdCommand(words, Quickshell.env("HOME"), 400);
			running = true;
		}

		stdout: StdioCollector {
			onStreamFinished: {
				pane.filesFor = fileProc.terms.join(" ");
				// Shown in yazi, the file under its cursor, not opened in an app.
				pane.files = Search.rankFiles(this.text.split("\n"), fileProc.terms, Quickshell.env("HOME"), 60).map(f => ({
					label: f.name,
					subtitle: f.dir,
					lineIcon: f.icon,
					run: () => Commands.spawn(["ghostty", "+new-window", "-e", "yazi", f.path])
				}));
			}
		}
		onExited: {
			if (pane.fileTerms !== null && pane.fileTerms.length > 0 && pane.fileTerms.join(" ") !== terms.join(" "))
				Qt.callLater(() => fileProc.search(pane.fileTerms));
		}
	}

	Process {
		id: pathProc
		command: ["bash", "-c", "compgen -c | sort -u"]
		stdout: StdioCollector {
			onStreamFinished: pane.pathCommands = this.text.split("\n").map(l => l.trim()).filter(l => l !== "")
		}
	}
}
