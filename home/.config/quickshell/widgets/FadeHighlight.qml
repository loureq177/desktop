import ".."
import QtQuick

// The highlight of one item, fading in while it is `selected` and out when
// it is not: each item has its own, where SelectionHighlight is one for a
// whole list that slides between them.
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
