import ".."
import QtQuick

// A line icon to click, the size of CloseButton, for panel headers. With a
// hotkey it is wider, and the key sits beside the icon as on the tiles.
Rectangle {
	id: root

	property string icon: ""
	property string hotkey: ""
	signal clicked()

	implicitWidth: hotkey !== "" ? 40 : 28
	implicitHeight: 28
	radius: Theme.roundingElement
	color: area.containsMouse ? Theme.bgHover : "transparent"

	Behavior on color { ColorAnimation { duration: Theme.animFast } }

	LineIcon {
		anchors.centerIn: parent
		anchors.horizontalCenterOffset: root.hotkey !== "" ? -5 : 0
		name: root.icon
		size: 15
		color: area.containsMouse ? Theme.textMain : Theme.textDim
	}

	HotkeyHint {
		anchors.right: parent.right
		anchors.bottom: parent.bottom
		anchors.rightMargin: 5
		anchors.bottomMargin: 3
		key: root.hotkey
		lit: area.containsMouse
	}

	MouseArea {
		id: area
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: root.clicked()
	}
}
