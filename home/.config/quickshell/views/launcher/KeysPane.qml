import "../.."
import "../../Search.js" as Search
import QtQuick

// Every key bind and key of the shell (Keybinds), to read. With nothing typed
// they come in sections, each under its heading; a search mixes them, by what
// the key does first, then by chord and section.
LauncherPane {
	id: pane

	readonly property string q: query.trim()

	icon: "keyboard"
	placeholder: "Search " + Keybinds.entries.length + " keys..."
	preferredHeight: list.preferredHeight

	function step(delta: int): void {
		list.step(delta);
	}

	// The line icon of a key: what it is pressed with.
	function keyIcon(category: string): string {
		return category === "Mouse" ? "mouse" : category === "Gestures" ? "hand" : "keyboard";
	}

	onQueryChanged: list.reset()

	ResultList {
		id: list
		anchors.fill: parent

		items: Search.rank(Keybinds.entries, e => Search.matchScore([[e.action, 0], [e.chord, 4], [e.category, 7]], pane.q)).map(e => ({
			label: e.action,
			subtitle: pane.q === "" ? "" : e.category,
			heading: pane.q === "" ? e.category : "",
			lineIcon: pane.keyIcon(e.category),
			chord: e.chord,
			run: () => false
		}))

		emptyText: Keybinds.loaded ? "No matching keys or actions" : "Loading keys..."
	}
}
