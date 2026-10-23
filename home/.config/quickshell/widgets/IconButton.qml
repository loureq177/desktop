import ".."
import QtQuick

// A square button with a line icon, lit under the pointer: outlined, or bare
// (`outlined: false`). `danger` turns it red under the pointer: what it does
// cannot be undone.
Rectangle {
	id: button

	property string icon: ""
	property int iconSize: 16
	property bool outlined: true
	property bool danger: false
	readonly property bool hovered: area.containsMouse
	property color iconColor: !hovered ? Theme.textDim : danger ? Theme.critical : Theme.textMain
	property real spin: 0

	signal clicked()

	implicitWidth: 32
	implicitHeight: 32
	radius: Theme.roundingSubtle
	color: hovered ? Theme.bgHover : "transparent"
	border.color: !outlined ? "transparent" : hovered ? Theme.tileBorderHover : Theme.tileBorder
	border.width: 1

	Behavior on color { ColorAnimation { duration: Theme.animFast } }

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
