import ".."
import QtQuick

// A thin line filled to `value` (0 to 1): the OSD's volume and brightness, the timer.
Rectangle {
	property real value: 0
	property color fill: Theme.accentBlue

	width: 180
	height: 4
	radius: 2
	color: Theme.alpha(Theme.textMain, 0.25)

	Rectangle {
		width: parent.width * Math.min(1, Math.max(0, parent.value))
		height: parent.height
		radius: parent.radius
		color: parent.fill

		Behavior on width {
			NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
		}
	}
}
