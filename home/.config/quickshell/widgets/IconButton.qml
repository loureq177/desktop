import ".."
import QtQuick

// A line icon to click, the size of CloseButton, for panel headers.
Rectangle {
	id: root

	property string icon: ""
	signal clicked()

	implicitWidth: 28
	implicitHeight: 28
	radius: Theme.roundingElement
	color: area.containsMouse ? Theme.bgHover : "transparent"

	Behavior on color { ColorAnimation { duration: 120 } }

	LineIcon {
		anchors.centerIn: parent
		name: root.icon
		size: 15
		color: area.containsMouse ? Theme.textMain : Theme.textDim
	}

	MouseArea {
		id: area
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: root.clicked()
	}
}
