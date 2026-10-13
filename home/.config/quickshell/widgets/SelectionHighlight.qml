import ".."
import QtQuick

Rectangle {
	property bool selected: false

	anchors.fill: parent
	radius: parent.radius
	color: Theme.selectionBg
	border.color: Theme.selectionBorder
	border.width: 1
	opacity: selected ? 1.0 : 0.0
	visible: opacity > 0.0
	z: 0

	Behavior on opacity {
		NumberAnimation {
			duration: 140
			easing.type: Easing.OutCubic
		}
	}
}
