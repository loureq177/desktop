import ".."
import QtQuick
import QtQuick.Controls

// Only while there is something to scroll: a view a pixel short of its rows (rounding) has nothing.
ScrollBar {
	visible: size < 0.99
	active: size < 0.99
	policy: ScrollBar.AsNeeded
	contentItem: Rectangle {
		implicitWidth: 4
		radius: Theme.roundingSubtle
		color: parent.hovered || parent.pressed ? Theme.textDim : Theme.border
	}
}
