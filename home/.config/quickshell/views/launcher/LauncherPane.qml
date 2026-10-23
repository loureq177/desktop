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
	// A grid: Left and Right move to the next cell, Up and Down by a row.
	property bool grid: false

	function step(delta: int): void {
	}

	function stepColumn(delta: int): void {
	}

	function activate(): void {
	}

	// The launcher opened on this list, or left it.
	function opened(): void {
	}

	function closed(): void {
	}
}
