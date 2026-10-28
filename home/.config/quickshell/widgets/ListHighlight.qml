import QtQuick

// The SelectionHighlight of a ListView's or GridView's current item. It
// lights the item's `highlightArea` when it has one (ListRow), else all of
// it; behind the items, or `over` them when they paint a background of their
// own (cards) that would hide it.
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
