import "../.."
import "../../widgets"
import QtQuick
import QtQuick.Layouts

Rectangle {
	id: row

	property bool current: false
	property string icon: ""
	property string label: ""
	property bool ready: false
	property bool muted: false
	property real value: 0
	property bool iconInteractive: false
	signal selectRequested()
	signal iconClicked()
	signal scrubbed(real v)

	Layout.fillWidth: true
	Layout.preferredHeight: 48
	radius: Theme.roundingElement
	color: "transparent"
	border.width: 0

	SelectionHighlight {
		selected: row.current
	}

	MouseArea {
		anchors.fill: parent
		z: 0
		onClicked: row.selectRequested()
	}

	RowLayout {
		anchors.fill: parent
		anchors.leftMargin: 4
		anchors.rightMargin: 8
		spacing: 10
		z: 1

		Rectangle {
			Layout.preferredWidth: 40
			Layout.preferredHeight: 40
			radius: Theme.roundingSubtle
			color: iconArea.containsMouse ? Theme.bgHover : "transparent"
			border.color: iconArea.containsMouse ? Theme.tileBorderHover : Theme.tileBorder
			border.width: 1
			opacity: row.ready ? 1.0 : 0.4

			LineIcon {
				anchors.centerIn: parent
				name: row.icon
				size: 22
				color: row.muted ? Theme.textDim : Theme.accentBlue
			}

			MouseArea {
				id: iconArea
				anchors.fill: parent
				enabled: row.iconInteractive
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: row.iconClicked()
			}
		}

		Item {
			Layout.fillWidth: true
			Layout.preferredHeight: 48
			Layout.alignment: Qt.AlignVCenter
			enabled: row.ready
			opacity: enabled ? 1.0 : 0.4

			Rectangle {
				id: track
				anchors.left: parent.left
				anchors.right: parent.right
				anchors.verticalCenter: parent.verticalCenter
				height: slideArea.pressed ? 22 : 20
				radius: Theme.roundingElement
				color: Theme.bgHover
				border.color: slideArea.containsMouse || slideArea.pressed ? Theme.tileBorderHover : Theme.tileBorder
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
					width: parent.width * Math.max(0, Math.min(100, row.value)) / 100
					radius: parent.radius
					color: row.muted ? Theme.textDim : Theme.accentBlue

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
					onPressed: mouse => row.scrubbed(Math.max(0, Math.min(100, mouse.x / track.width * 100)))
					onPositionChanged: mouse => {
						if (pressed)
							row.scrubbed(Math.max(0, Math.min(100, mouse.x / track.width * 100)));
					}
				}
			}
		}

		Text {
			Layout.preferredWidth: 56
			horizontalAlignment: Text.AlignRight
			text: row.label
			font.family: Theme.fontMono
			font.pixelSize: Theme.fontSizeSmall + 1
			font.bold: true
			color: Theme.textMain
		}
	}
}
