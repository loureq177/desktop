import ".."
import QtQuick

// The charge at a glance, or as a number with `showPercent`. Below 15% the empty part glows too.
// Nothing on a machine without a battery.
Swap {
	id: root

	property bool showPercent: false
	property color color: Battery.color

	Behavior on color {
		ColorAnimation { duration: Theme.animFast }
	}

	visible: Battery.present
	swapped: showPercent
	alt: Battery.percent + "%"
	altColor: color

	Item {
		width: 28
		height: 12

		Rectangle {
			x: 2
			y: 2
			width: 21
			height: 8
			radius: 1
			visible: Battery.critical
			color: Theme.alpha(Theme.critical, 0.35)
		}
		Rectangle {
			width: 25
			height: 12
			radius: 3
			color: "transparent"
			border.width: 1.4
			border.color: root.color
		}
		Rectangle {
			x: 26
			y: 4
			width: 2
			height: 4
			radius: 1
			color: root.color
		}
		Rectangle {
			x: 3
			y: 3
			width: 19 * Battery.percent / 100
			height: 6
			radius: 1
			color: root.color

			Behavior on width {
				NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
			}
		}
	}
}
