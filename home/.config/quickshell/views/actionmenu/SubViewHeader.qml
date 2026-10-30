import "../.."
import "../../widgets"
import QtQuick
import QtQuick.Layouts

RowLayout {
	id: root

	property string title: ""
	property string subtitle: ""
	property bool enabledState: false
	property bool isScanning: false
	// The key that flips the switch, shown beside it.
	property string toggleKey: ""

	signal backClicked()
	signal toggleClicked()

	Layout.fillWidth: true
	Layout.preferredHeight: 34
	spacing: 10

	IconButton {
		icon: "arrow-left"
		iconSize: 18
		onClicked: root.backClicked()
	}

	ColumnLayout {
		spacing: 0

		StyledText {
			text: root.title
			font.pixelSize: Theme.fontSizeLarge
			font.bold: true
		}

		StyledText {
			visible: root.subtitle !== ""
			text: root.subtitle
			mono: true
			font.pixelSize: Theme.fontSizeTiny
			color: root.isScanning ? Theme.accentBlue : Theme.textDim
		}
	}

	Item {
		Layout.fillWidth: true
	}

	HotkeyHint {
		key: root.toggleKey
	}

	Rectangle {
		Layout.preferredWidth: 44
		Layout.preferredHeight: 24
		radius: 12
		color: root.enabledState ? Theme.accentBlue : Theme.bgHover
		border.color: root.enabledState ? Theme.accentBlue : Theme.border
		border.width: 1

		Behavior on color { ColorAnimation { duration: Theme.animFast } }
		Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

		Rectangle {
			width: 18
			height: 18
			radius: 9
			x: root.enabledState ? parent.width - width - 3 : 3
			anchors.verticalCenter: parent.verticalCenter
			color: root.enabledState ? Theme.bgMain : Theme.textDim

			Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
			Behavior on color { ColorAnimation { duration: Theme.animFast } }
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor
			onClicked: root.toggleClicked()
		}
	}
}
