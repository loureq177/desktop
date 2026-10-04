// Capture sub-menu: provides screenshot (interactive region/window & fullscreen),
// screen recording, color picker, OCR, and voice dictation tools.
// Full Vim key navigation (h/j/k/l, Enter, Space, Esc, q).
import "../.."
import "../../widgets"
import "."
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
	id: root

	signal backRequested()
	signal closeRequested()

	property int currentIndex: 0
	focus: true

	readonly property var captureActions: [
		{
			id: "screenshot",
			title: "Screenshot",
			desc: "Interactive window or region capture",
			icon: "󰄀",
			isRecording: false,
			cmd: "sleep 0.15 && ~/.local/bin/screenshot region"
		},
		{
			id: "fullscreen",
			title: "Fullscreen",
			desc: "Capture entire focused display",
			icon: "󰹑",
			isRecording: false,
			cmd: "sleep 0.15 && ~/.local/bin/screenshot fullscreen"
		},
		{
			id: "record",
			title: "Screen Record",
			desc: SystemStatus.recording ? "Recording active • Click to stop" : "Record video of area or screen",
			icon: SystemStatus.recording ? "󰻃" : "󰕧",
			isRecording: SystemStatus.recording,
			cmd: "~/.local/bin/record-screen toggle"
		},
		{
			id: "colorpicker",
			title: "Color Picker",
			desc: "Pick screen color & copy HEX to clipboard",
			icon: "󰈊",
			isRecording: false,
			cmd: "sleep 0.15 && hyprpicker -a --notify"
		},
		{
			id: "ocr",
			title: "Text OCR",
			desc: "Select area & copy extracted text to clipboard",
			icon: "󰚢",
			isRecording: false,
			cmd: "sleep 0.15 && ~/.local/bin/ocr"
		},
		{
			id: "dictation",
			title: "Voice Dictation",
			desc: "Transcribe voice into focused application",
			icon: "󰍬",
			isRecording: false,
			cmd: "~/.local/bin/dictation"
		}
	]

	readonly property int preferredHeight: 460

	onVisibleChanged: {
		if (visible) {
			currentIndex = 0;
			root.forceActiveFocus();
		}
	}

	function runCommand(cmd) {
		// Snap the panel shut with no animation: these tools freeze the
		// screen (hyprpicker/slurp), which would otherwise capture a cut
		// animation mid-flight.
		QuickSettings.closeInstant();
		Quickshell.execDetached(["sh", "-c", cmd]);
	}

	function activateCurrent() {
		var item = captureActions[currentIndex];
		if (!item || !item.cmd) return;
		runCommand(item.cmd);
	}

	// ─── Vim Key Navigation ──────────────────────────────────────────
	Keys.onPressed: event => {
		if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
			root.currentIndex = Math.min(root.captureActions.length - 1, root.currentIndex + 1);
			event.accepted = true;
		} else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
			root.currentIndex = Math.max(0, root.currentIndex - 1);
			event.accepted = true;
		} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
			root.activateCurrent();
			event.accepted = true;
		} else if (event.key === Qt.Key_Escape || event.key === Qt.Key_H || event.key === Qt.Key_Q || event.key === Qt.Key_Back) {
			root.backRequested();
			event.accepted = true;
		}
	}

	ColumnLayout {
		anchors.fill: parent
		spacing: 12

		SubViewHeader {
			Layout.fillWidth: true
			title: "Capture"
			subtitle: ""
			enabledState: true
			showPowerSwitch: false
			showScan: false
			onBackClicked: root.backRequested()
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 1
			color: Theme.border
		}

		ListView {
			id: captureList
			Layout.fillWidth: true
			Layout.fillHeight: true
			clip: true
			spacing: 6
			model: root.captureActions
			currentIndex: root.currentIndex
			boundsBehavior: Flickable.DragAndOvershootBounds

			delegate: Rectangle {
				id: actionRow
				required property var modelData
				required property int index
				readonly property bool isSelected: index === root.currentIndex

				width: ListView.view.width
				implicitHeight: actionCol.implicitHeight + 20
				radius: Theme.roundingElement
				color: modelData.isRecording
					? Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.18)
					: (rowHover.containsMouse ? Theme.bgHover : Theme.bgMain)
				border.color: modelData.isRecording
					? Theme.critical
					: (rowHover.containsMouse ? Theme.textDim : Theme.border)
				border.width: 1

				Behavior on color { ColorAnimation { duration: 120 } }
				Behavior on border.color { ColorAnimation { duration: 120 } }

				Rectangle {
					anchors.fill: parent
					radius: parent.radius
					color: Theme.selectionBg
					border.color: Theme.selectionBorder
					border.width: 1
					opacity: actionRow.isSelected ? 1.0 : 0.0
					visible: opacity > 0.0
					z: 0

					Behavior on opacity {
						NumberAnimation {
							duration: 140
							easing.type: Easing.OutCubic
						}
					}
				}

				MouseArea {
					id: rowHover
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					z: 1
					onClicked: {
						root.currentIndex = index;
						if (modelData.cmd) {
							root.runCommand(modelData.cmd);
						}
					}
				}

				RowLayout {
					id: actionCol
					anchors.fill: parent
					anchors.margins: 10
					spacing: 12

					// Icon
					Text {
						text: modelData.icon
						font.family: Theme.fontFamily
						font.pixelSize: 22
						color: modelData.isRecording ? Theme.critical : (modelData.id === "dictation" ? Theme.accentGreen : Theme.accentBlue)
						Layout.preferredWidth: 32
						horizontalAlignment: Text.AlignHCenter
					}

					// Title & description
					ColumnLayout {
						Layout.fillWidth: true
						spacing: 2

						Text {
							text: modelData.title
							font.family: Theme.fontFamily
							font.pixelSize: Theme.fontSize
							font.bold: true
							color: Theme.textMain
						}

						Text {
							text: modelData.desc
							font.family: Theme.fontMono
							font.pixelSize: Theme.fontSizeSmall - 2
							color: Theme.textDim
							elide: Text.ElideRight
							Layout.fillWidth: true
						}
					}
				}
			}
		}
	}
}
