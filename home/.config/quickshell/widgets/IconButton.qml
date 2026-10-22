import ".."
import QtQuick

// A square button with a line icon, outlined, lit under the pointer.
Rectangle {
	id: button

	property string icon: ""
	property int iconSize: 16
	readonly property bool hovered: area.containsMouse
	property color iconColor: hovered ? Theme.textMain : Theme.textDim
	property real spin: 0

	signal clicked()

	implicitWidth: 32
	implicitHeight: 32
	radius: Theme.roundingSubtle
	color: hovered ? Theme.bgHover : "transparent"
	border.color: hovered ? Theme.tileBorderHover : Theme.tileBorder
	border.width: 1

	LineIcon {
		anchors.centerIn: parent
		name: button.icon
		size: button.iconSize
		color: button.iconColor
		rotation: button.spin
	}

	MouseArea {
		id: area
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: button.clicked()
	}
}
