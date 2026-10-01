// Shared off-state placeholder for quick settings sub-menus (Wi-Fi, Bluetooth).
import "../.."
import QtQuick
import QtQuick.Layouts

Item {
	id: root

	property string icon: ""
	property string title: ""
	property string subtitle: ""
	property string buttonText: ""
	property string hintText: ""

	signal enableClicked()

	Layout.fillWidth: true
	Layout.fillHeight: true

	ColumnLayout {
		anchors.centerIn: parent
		spacing: 12

		Text {
			Layout.alignment: Qt.AlignHCenter
			text: root.icon
			font.family: Theme.fontFamily
			font.pixelSize: 48
			color: Theme.textMuted
		}

		Text {
			Layout.alignment: Qt.AlignHCenter
			text: root.title
			font.family: Theme.fontFamily
			font.pixelSize: Theme.fontSize
			font.bold: true
			color: Theme.textMain
		}

		Text {
			Layout.alignment: Qt.AlignHCenter
			text: root.subtitle
			font.family: Theme.fontMono
			font.pixelSize: Theme.fontSizeSmall
			color: Theme.textDim
		}

		Rectangle {
			Layout.alignment: Qt.AlignHCenter
			Layout.topMargin: 8
			implicitWidth: enableBtnText.implicitWidth + 24
			implicitHeight: 34
			radius: Theme.roundingElement
			color: enableBtnArea.containsMouse ? Qt.lighter(Theme.accentBlue, 1.15) : Theme.accentBlue

			Text {
				id: enableBtnText
				anchors.centerIn: parent
				text: root.buttonText
				font.family: Theme.fontFamily
				font.pixelSize: Theme.fontSizeSmall
				font.bold: true
				color: Theme.bgMain
			}

			MouseArea {
				id: enableBtnArea
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: root.enableClicked()
			}
		}

		Text {
			Layout.alignment: Qt.AlignHCenter
			Layout.topMargin: 4
			text: root.hintText
			font.family: Theme.fontMono
			font.pixelSize: Theme.fontSizeSmall - 2
			color: Theme.textMuted
		}
	}
}
