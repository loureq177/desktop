import QtQuick

// One of the launcher's lists. The field's text comes in as `query`; the rest
// says what the field shows and what its keys do here.
Item {
	property string query: ""
	property string icon: "search"
	property string placeholder: ""
	// As tall as the list would like to be, up to the launcher's height.
	property int preferredHeight: 0
	// What the picked row does, under the list (two lines at most), or nothing.
	property string footer: ""
	// Room for the footer even while it is empty: a list of rows that mostly have one.
	property bool keepFooter: false
	// Somewhere to step back to: the field's icon is an arrow then, as Esc or Backspace.
	property bool canGoBack: false
	// What went wrong, in red under the list, or nothing.
	property string error: ""
	// A grid: Left and Right move to the next cell, Up and Down by a row.
	property bool grid: false

	// The field's text, set from here (a value to edit).
	signal queryRequested(string text)

	// `repeat`: the key is held down.
	function step(delta: int, repeat: bool): void {
	}

	function stepColumn(delta: int, repeat: bool): void {
	}

	function tab(delta: int, repeat: bool): void {
		step(delta, repeat);
	}

	function activate(): void {
	}

	// Escape, or Backspace when empty: true when the list stepped back on its own
	// (out of an edit), keeping the launcher open.
	function back(): bool {
		return false;
	}

	// Its tab clicked while open: true when it went back to its start, false when it was there.
	function home(): bool {
		if (query === "")
			return false;
		queryRequested("");
		return true;
	}

	// Ctrl+R: what the selected row holds, back to its default.
	function resetValue(): void {
	}

	// Delete: the selected row goes, on the second press.
	function removeValue(): void {
	}

	// The launcher opened on this list, or left it.
	function opened(): void {
	}

	function closed(): void {
	}
}
