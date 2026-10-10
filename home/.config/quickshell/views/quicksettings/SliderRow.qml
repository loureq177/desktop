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
	property real maxValue: 100
	property bool iconInteractive: false
	property alias slider: pillSlider
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
			border.color: iconArea.containsMouse ? Theme.textDim : Theme.border
			border.width: 1
			opacity: row.ready ? 1.0 : 0.4

			Text {
				anchors.centerIn: parent
				text: row.icon
				font.family: Theme.fontFamily
				font.pixelSize: 22
				font.bold: true
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

		PillSlider {
			id: pillSlider
			value: row.value
			maxValue: row.maxValue
			ready: row.ready
			muted: row.muted
			fillColor: Theme.accentBlue
			onScrubbed: v => row.scrubbed(v)
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
