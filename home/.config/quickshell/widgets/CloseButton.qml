import ".."
import QtQuick

Rectangle {
	id: root

	signal clicked()

	property int size: 28

	implicitWidth: size
	implicitHeight: size
	radius: size >= 24 ? Theme.roundingElement : Theme.roundingSubtle
	color: mouseArea.containsMouse ? Theme.bgHover : "transparent"

	Behavior on color { ColorAnimation { duration: Theme.animFast } }

	LineIcon {
		anchors.centerIn: parent
		name: "x"
		size: root.size >= 26 ? 14 : 11
		color: mouseArea.containsMouse ? Theme.critical : (root.size >= 26 ? Theme.textDim : Theme.textMuted)
	}

	MouseArea {
		id: mouseArea
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: mouse => {
			mouse.accepted = true;
			root.clicked();
		}
	}
}
