import ".."
import QtQuick
import QtQuick.Controls

ScrollBar {
	visible: size < 1.0
	active: size < 1.0
	policy: ScrollBar.AsNeeded
	contentItem: Rectangle {
		implicitWidth: 4
		radius: Theme.roundingSubtle
		color: parent.hovered || parent.pressed ? Theme.textDim : Theme.border
	}
}
