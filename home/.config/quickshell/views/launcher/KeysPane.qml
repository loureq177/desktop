import "../.."
import "../../Search.js" as Search
import QtQuick

// Every key bind and key of the shell (Keybinds), to read. With nothing typed
// they come in sections, each under its heading; a search mixes them, by what
// the key does first, then by chord and section.
ResultList {
	id: pane

	property string query: ""
	readonly property string q: query.trim()

	readonly property string icon: "keyboard"
	readonly property string placeholder: "Search " + Keybinds.entries.length + " keys..."

	// The line icon of a key: what it is pressed with.
	function keyIcon(category: string): string {
		return category === "Mouse" ? "mouse" : category === "Gestures" ? "hand" : "keyboard";
	}

	// The action with the letter of its key lit where a word starts with it,
	// the last such word first (Toggle notification center: the N of notification),
	// so the name says the key. Nothing when no word does.
	function mnemonicOf(e: var): string {
		var key = e.chord.split(" + ").pop();
		if (!/^[A-Z]$/.test(key))
			return "";
		var at = -1;
		var re = new RegExp("\\b" + key, "gi");
		for (var m = re.exec(e.action); m !== null; m = re.exec(e.action))
			at = m.index;
		if (at === -1)
			return "";
		return e.action.substring(0, at) + "<font color=\"" + Theme.accentBlue + "\"><b>" + e.action[at] + "</b></font>" + e.action.substring(at + 1);
	}

	onQueryChanged: reset()

	items: Search.rank(Keybinds.entries, e => Search.matchScore([[e.action, 0], [e.chord, 4], [e.category, 7]], q)).map(e => ({
		label: e.action,
		mnemonic: mnemonicOf(e),
		subtitle: q === "" ? "" : e.category,
		heading: q === "" ? e.category : "",
		lineIcon: keyIcon(e.category),
		chord: e.chord,
		run: () => false
	}))

	emptyText: Keybinds.loaded ? "No matching keys or actions" : "Loading keys..."
}
