import "../.."
import QtQuick
import QtQuick.Layouts

Item {
	property string title: ""
	property string hint: ""

	ColumnLayout {
		anchors.centerIn: parent
		spacing: 8

		Text {
			Layout.alignment: Qt.AlignHCenter
			text: title
			font.family: Theme.fontFamily
			font.pixelSize: Theme.fontSizeSmall
			color: Theme.textDim
		}

		Text {
			Layout.alignment: Qt.AlignHCenter
			text: hint
			font.family: Theme.fontMono
			font.pixelSize: Theme.fontSizeSmall - 2
			color: Theme.textMuted
		}
	}
}
