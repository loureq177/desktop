import "../.."
import "../../Search.js" as Search
import QtQuick

// The session's commands (lock, suspend, log out, reboot, power off); the last three ask twice.
LauncherPane {
	id: pane

	icon: "power"
	placeholder: "Search…"
	preferredHeight: list.preferredHeight

	function step(delta: int, repeat: bool): void {
		list.step(delta, repeat);
	}

	function activate(): void {
		list.activate();
	}

	function opened(): void {
		list.rewind();
	}

	onQueryChanged: list.reset()

	ResultList {
		id: list
		anchors.fill: parent
		emptyText: "Nothing matches"
		items: Search.rank(Commands.all.filter(c => c.group === "session" && c.id !== "power").map(c => ({
			label: c.name,
			lineIcon: c.icon,
			keywords: c.keywords,
			confirm: c.confirm,
			chord: c.bind ? Keybinds.chordFor(c.bind) : "",
			run: c.run
		})), it => Search.itemScore(it, pane.query))
	}
}
