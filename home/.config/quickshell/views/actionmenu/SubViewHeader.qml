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
	property bool showPowerSwitch: true
	property bool showScan: true
	// The keys that scan and flip the switch, shown beside them.
	property string scanKey: ""
	property string toggleKey: ""

	signal backClicked()
	signal scanClicked()
	signal toggleClicked()

	Layout.fillWidth: true
	Layout.preferredHeight: 34
	spacing: 10

	Rectangle {
		Layout.preferredWidth: 32
		Layout.preferredHeight: 32
		radius: Theme.roundingSubtle
		color: backArea.containsMouse ? Theme.bgHover : "transparent"
		border.color: backArea.containsMouse ? Theme.tileBorderHover : Theme.tileBorder
		border.width: 1

		LineIcon {
			anchors.centerIn: parent
			name: "arrow-left"
			size: 18
			color: backArea.containsMouse ? Theme.textMain : Theme.textDim
		}

		MouseArea {
			id: backArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: root.backClicked()
		}
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
		key: root.showScan && root.enabledState ? root.scanKey : ""
		lit: scanArea.containsMouse
	}

	Rectangle {
		Layout.preferredWidth: 32
		Layout.preferredHeight: 32
		radius: Theme.roundingSubtle
		color: scanArea.containsMouse ? Theme.bgHover : "transparent"
		border.color: scanArea.containsMouse ? Theme.tileBorderHover : Theme.tileBorder
		border.width: 1
		visible: root.showScan && root.enabledState

		LineIcon {
			id: scanIcon
			anchors.centerIn: parent
			name: "refresh-cw"
			size: 16
			color: root.isScanning ? Theme.accentBlue : (scanArea.containsMouse ? Theme.textMain : Theme.textDim)

			RotationAnimation on rotation {
				running: root.isScanning
				loops: Animation.Infinite
				from: 0
				to: 360
				duration: 900
			}
		}

		MouseArea {
			id: scanArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: root.scanClicked()
		}
	}

	HotkeyHint {
		key: root.showPowerSwitch ? root.toggleKey : ""
	}

	Rectangle {
		id: powerSwitch
		visible: root.showPowerSwitch
		Layout.preferredWidth: 44
		Layout.preferredHeight: 24
		radius: 12
		color: root.enabledState ? Theme.accentBlue : Theme.bgHover
		border.color: root.enabledState ? Theme.accentBlue : Theme.border
		border.width: 1

		Behavior on color { ColorAnimation { duration: Theme.animFast } }
		Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

		Rectangle {
			id: switchThumb
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
