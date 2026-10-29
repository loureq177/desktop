import QtQuick

// Lights the current item's `highlightArea` (or all of it); behind the items, or
// `over` them when they paint their own background.
SelectionHighlight {
	required property var view
	property bool over: false

	readonly property Item area: item?.highlightArea ?? item

	item: view.currentItem
	parent: view.contentItem
	// Delegates sit at z 1.
	z: over ? 2 : 0
	x: item ? item.x + (area === item ? 0 : area.x) : 0
	y: item ? item.y + (area === item ? 0 : area.y) : 0
	width: area?.width ?? 0
	height: area?.height ?? 0
}
