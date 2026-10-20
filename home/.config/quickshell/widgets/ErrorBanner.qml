import ".."
import QtQuick
import QtQuick.Layouts

Rectangle {
	property string message: ""

	Layout.fillWidth: true
	radius: Theme.roundingElement
	color: Theme.alpha(Theme.critical, 0.10)
	border.color: Theme.alpha(Theme.critical, 0.40)
	border.width: 1
	implicitHeight: row.implicitHeight + 16

	RowLayout {
		id: row
		anchors.fill: parent
		anchors.margins: 8
		spacing: 8

		Text {
			text: "⚠"
			font.pixelSize: Theme.fontSizeSmall
			color: Theme.critical
		}
		StyledText {
			Layout.fillWidth: true
			text: message
			mono: true
			font.pixelSize: Theme.fontSizeTiny
			color: Theme.critical
			elide: Text.ElideRight
		}
	}
}
