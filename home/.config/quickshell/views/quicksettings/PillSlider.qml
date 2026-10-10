import "../.."
import QtQuick
import QtQuick.Layouts

Item {
	id: pill

	property real value: 0
	property real maxValue: 100
	property bool ready: false
	property bool muted: false
	property color fillColor: Theme.accentBlue
	property alias pressed: slideArea.pressed
	property alias hovered: slideArea.containsMouse
	signal scrubbed(real v)

	Layout.fillWidth: true
	Layout.preferredHeight: 48
	Layout.alignment: Qt.AlignVCenter
	enabled: pill.ready
	opacity: enabled ? 1.0 : 0.4

	function ratioToValue(rx: real): real {
		return Math.max(0, Math.min(pill.maxValue, Math.round(rx / track.width * pill.maxValue)));
	}

	Rectangle {
		id: track
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter
		height: pill.pressed ? 22 : 20
		radius: Theme.roundingElement
		color: Theme.bgHover
		border.color: slideArea.containsMouse || pill.pressed ? Theme.textDim : Theme.border
		border.width: 1
		clip: true

		Behavior on height {
			NumberAnimation { duration: 100 }
		}
		Behavior on border.color {
			ColorAnimation { duration: 120 }
		}

		Rectangle {
			anchors.left: parent.left
			anchors.top: parent.top
			anchors.bottom: parent.bottom
			width: parent.width * Math.max(0, Math.min(pill.maxValue, pill.value)) / pill.maxValue
			radius: parent.radius
			color: pill.muted ? Theme.textDim : pill.fillColor

			Behavior on color {
				ColorAnimation { duration: 120 }
			}
		}

		MouseArea {
			id: slideArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			preventStealing: true
			onPressed: mouse => pill.scrubbed(pill.ratioToValue(mouse.x))
			onPositionChanged: mouse => {
				if (pressed)
					pill.scrubbed(pill.ratioToValue(mouse.x));
			}
		}
	}
}
