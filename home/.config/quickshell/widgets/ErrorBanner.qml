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
		Text {
			Layout.fillWidth: true
			text: message
			font.family: Theme.fontMono
			font.pixelSize: Theme.fontSizeSmall - 1
			color: Theme.critical
			elide: Text.ElideRight
		}
	}
}
