import "../.."
import QtQuick
import QtQuick.Layouts

RowLayout {
	id: actions

	property bool isConnected: false
	property bool isSelected: false
	property bool canForget: false
	property bool busy: false
	signal disconnectClicked()
	signal forgetClicked()

	spacing: 6

	Rectangle {
		visible: actions.isConnected
		implicitWidth: disLabel.implicitWidth + 14
		implicitHeight: 26
		radius: Theme.roundingSubtle
		color: disArea.containsMouse ? Theme.bgCard : "transparent"
		border.color: disArea.containsMouse ? Theme.textDim : Theme.border
		border.width: 1

		Text {
			id: disLabel
			anchors.centerIn: parent
			text: "Disconnect"
			font.family: Theme.fontFamily
			font.pixelSize: Theme.fontSizeSmall - 2
			color: Theme.textMain
		}

		MouseArea {
			id: disArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: mouse => {
				mouse.accepted = true;
				actions.disconnectClicked();
			}
		}
	}

	Rectangle {
		visible: actions.canForget || actions.isConnected
		implicitWidth: 26
		implicitHeight: 26
		radius: Theme.roundingSubtle
		color: fArea.containsMouse ? Theme.bgCard : "transparent"
		border.color: fArea.containsMouse ? Theme.critical : "transparent"
		border.width: 1

		Text {
			anchors.centerIn: parent
			text: "󰆴"
			font.family: Theme.fontFamily
			font.pixelSize: 14
			color: fArea.containsMouse ? Theme.critical : Theme.textDim
		}

		MouseArea {
			id: fArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: mouse => {
				mouse.accepted = true;
				actions.forgetClicked();
			}
		}
	}

	Text {
		visible: !actions.isConnected && !actions.busy
		text: "›"
		font.family: Theme.fontFamily
		font.pixelSize: 18
		color: actions.isSelected ? Theme.accentBlue : Theme.textMuted
	}
}
