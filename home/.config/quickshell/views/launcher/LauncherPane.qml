import QtQuick

// One of the launcher's lists. The field's text comes in as `query`; the rest
// says what the field shows and what its keys do here.
Item {
	property string query: ""
	property string icon: "search"
	property string placeholder: ""
	// As tall as the list would like to be, up to the launcher's height.
	property int preferredHeight: 0
	// A line under the list, or nothing.
	property string footer: ""
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
