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

	property int currentIndex: 0
	focus: true

	// The panel is gone by the time the area picker comes up.
	readonly property string recordCmd: "sleep 0.15 && ~/.local/bin/record-screen"
	readonly property var recordActions: SystemStatus.recording ? [
		{
			id: "record",
			title: "Stop Recording",
			desc: "Save the screen recording",
			icon: "circle-stop",
			isRecording: true,
			cmd: "~/.local/bin/record-screen"
		}
	] : [
		{
			id: "record",
			title: "Screen Record",
			desc: "Record an area or a window",
			icon: "video",
			isRecording: false,
			cmd: recordCmd
		},
		{
			id: "record",
			title: "Screen Record + Microphone",
			desc: "With the microphone mixed in",
			icon: "mic",
			isRecording: false,
			cmd: recordCmd + " --mic"
		},
		{
			id: "record",
			title: "Screen Record + Microphone + Camera",
			desc: "With the microphone and a camera overlay",
			icon: "webcam",
			isRecording: false,
			cmd: recordCmd + " --mic --cam"
		}
	]

	readonly property var captureActions: [
		{
			id: "screenshot",
			title: "Screenshot",
			desc: "Interactive window or region capture",
			icon: "camera",
			isRecording: false,
			cmd: "sleep 0.15 && ~/.local/bin/screenshot region"
		}
	].concat(recordActions, [
		{
			id: "colorpicker",
			title: "Color Picker",
			desc: "Pick screen color & copy HEX to clipboard",
			icon: "pipette",
			isRecording: false,
			cmd: "sleep 0.15 && hyprpicker -a --notify"
		},
		{
			id: "ocr",
			title: "Text OCR",
			desc: "Select area & copy extracted text to clipboard",
			icon: "scan-text",
			isRecording: false,
			cmd: "sleep 0.15 && ~/.local/bin/ocr"
		},
		{
			id: "dictation",
			title: "Voice Dictation",
			desc: "Transcribe voice into focused application",
			icon: "mic",
			isRecording: false,
			cmd: "~/.local/bin/dictation"
		}
	])

	readonly property int preferredHeight: 60 + captureActions.length * 66

	onVisibleChanged: {
		if (visible) {
			currentIndex = 0;
			root.forceActiveFocus();
		}
	}

	function runCommand(cmd) {
		Panels.closeInstant();
		Quickshell.execDetached(["sh", "-c", cmd]);
	}

	function activateCurrent() {
		var item = captureActions[currentIndex];
		if (!item || !item.cmd) return;
		runCommand(item.cmd);
	}

	Keys.onPressed: event => {
		if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
			root.currentIndex = Math.min(root.captureActions.length - 1, root.currentIndex + 1);
			event.accepted = true;
		} else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
			root.currentIndex = Math.max(0, root.currentIndex - 1);
			event.accepted = true;
		} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
			if (!event.isAutoRepeat)
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
					? Theme.alpha(Theme.critical, 0.18)
					: (rowHover.containsMouse ? Theme.bgHover : Theme.inset(Theme.bgMain))
				border.color: modelData.isRecording
					? Theme.critical
					: (rowHover.containsMouse ? Theme.tileBorderHover : Theme.tileBorder)
				border.width: 1

				Behavior on color { ColorAnimation { duration: 120 } }
				Behavior on border.color { ColorAnimation { duration: 120 } }

				SelectionHighlight {
					selected: actionRow.isSelected
				}

				MouseArea {
					id: rowHover
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					z: 1
					onClicked: mouse => {
						mouse.accepted = true;
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
					z: 2

					LineIcon {
						name: modelData.icon
						size: 22
						color: modelData.isRecording ? Theme.critical : (modelData.id === "dictation" ? Theme.accentGreen : Theme.accentBlue)
						Layout.preferredWidth: 32
					}

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
