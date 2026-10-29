import ".."
import QtQuick

// One item's own highlight, fading with `selected` (SelectionHighlight slides for a list).
Rectangle {
	property bool selected: false

	anchors.fill: parent
	radius: parent.radius
	color: Theme.selectionBg
	border.color: Theme.selectionBorder
	border.width: 1
	opacity: selected ? 1.0 : 0.0
	visible: opacity > 0.0

	Behavior on opacity {
		NumberAnimation {
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}
	}
}
