import ".."
import QtQuick

// The charge at a glance; with `percent`, its number inside the battery.
// Below 15% the empty part glows too. Nothing on a machine without a battery.
Item {
	id: root

	property color color: Battery.color
	property bool percent: false

	Behavior on color {
		ColorAnimation { duration: Theme.animFast }
	}

	visible: Battery.present
	width: percent ? 37 : 28
	height: percent ? 18 : 12

	// The glyph: an outline, its nub and the charge.
	Item {
		visible: !root.percent
		anchors.fill: parent

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

	// With the number: no outline, the body is the empty part and the charge in two soft
	// tints of the colour, so the white number reads over both.
	Item {
		id: numbered
		visible: root.percent
		anchors.fill: parent
		readonly property int bodyWidth: 34

		Rectangle {
			width: numbered.bodyWidth
			height: parent.height
			radius: 4
			color: Theme.alpha(root.color, 0.22)
		}
		Item {
			width: numbered.bodyWidth * Battery.percent / 100
			height: parent.height
			clip: true

			Behavior on width {
				NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
			}

			Rectangle {
				width: numbered.bodyWidth
				height: parent.height
				radius: 4
				color: Theme.alpha(root.color, 0.55)
			}
		}
		Rectangle {
			x: numbered.bodyWidth + 1
			y: (parent.height - height) / 2
			width: 2
			height: 7
			radius: 1
			color: Theme.alpha(root.color, Battery.percent >= 99 ? 0.55 : 0.22)
		}
		// The bar's own type, as the clock beside it.
		StyledText {
			width: numbered.bodyWidth
			height: parent.height
			horizontalAlignment: Text.AlignHCenter
			verticalAlignment: Text.AlignVCenter
			text: Battery.percent
			font.bold: true
			font.pixelSize: 13
			color: "white"
		}
	}
}
