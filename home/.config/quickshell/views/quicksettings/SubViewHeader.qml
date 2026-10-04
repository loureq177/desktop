// Shared header for quick settings sub-menus (Wi-Fi, Bluetooth, Capture).
// Contains back button, title, and optional subtitle on the left,
// with secondary controls (scan button, power switch) aligned to the right.
// Sub-menus do not have a close button (user navigates back or clicks outside/ESC).
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

	signal backClicked()
	signal scanClicked()
	signal toggleClicked()

	Layout.fillWidth: true
	Layout.preferredHeight: 34
	spacing: 10

	// Back button
	Rectangle {
		Layout.preferredWidth: 32
		Layout.preferredHeight: 32
		radius: Theme.roundingSubtle
		color: backArea.containsMouse ? Theme.bgHover : "transparent"
		border.color: backArea.containsMouse ? Theme.textDim : Theme.border
		border.width: 1

		Text {
			anchors.centerIn: parent
			text: "󰁍"
			font.family: Theme.fontFamily
			font.pixelSize: 18
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

	// Title & status
	ColumnLayout {
		spacing: 0

		Text {
			text: root.title
			font.family: Theme.fontFamily
			font.pixelSize: Theme.fontSize + 1
			font.bold: true
			color: Theme.textMain
		}

		Text {
			visible: root.subtitle !== ""
			text: root.subtitle
			font.family: Theme.fontMono
			font.pixelSize: Theme.fontSizeSmall - 2
			color: root.isScanning ? Theme.accentBlue : Theme.textDim
		}
	}

	// Spacer pushing controls to the far right
	Item {
		Layout.fillWidth: true
	}

	// Scan / Refresh button
	Rectangle {
		Layout.preferredWidth: 32
		Layout.preferredHeight: 32
		radius: Theme.roundingSubtle
		color: scanArea.containsMouse ? Theme.bgHover : "transparent"
		border.color: scanArea.containsMouse ? Theme.textDim : Theme.border
		border.width: 1
		visible: root.showScan && root.enabledState

		Text {
			id: scanIcon
			anchors.centerIn: parent
			text: "󰑐"
			font.family: Theme.fontFamily
			font.pixelSize: 16
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

	// Power Switch Pill
	Rectangle {
		id: powerSwitch
		visible: root.showPowerSwitch
		Layout.preferredWidth: 44
		Layout.preferredHeight: 24
		radius: 12
		color: root.enabledState ? Theme.accentBlue : Theme.bgHover
		border.color: root.enabledState ? Theme.accentBlue : Theme.border
		border.width: 1

		Behavior on color { ColorAnimation { duration: 140 } }
		Behavior on border.color { ColorAnimation { duration: 120 } }

		Rectangle {
			id: switchThumb
			width: 18
			height: 18
			radius: 9
			x: root.enabledState ? parent.width - width - 3 : 3
			anchors.verticalCenter: parent.verticalCenter
			color: root.enabledState ? Theme.bgMain : Theme.textDim

			Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
			Behavior on color { ColorAnimation { duration: 140 } }
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor
			onClicked: root.toggleClicked()
		}
	}
}
