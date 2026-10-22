import ".."
import "../widgets"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
	id: win

	property string kind: ""
	property int value: 0
	property bool muted: false
	property bool shown: false

	readonly property string icon: kind === "brightness" ? "sun"
		: kind === "mic" ? (muted ? "mic-off" : "mic")
		: SystemStatus.volumeIcon(value, muted)

	// Actions has sliders for both, which show the change already.
	function show(newKind, newValue, newMuted) {
		if ((newKind === "volume" || newKind === "brightness") && Panels.active === "actions")
			return;
		kind = newKind;
		if (newValue !== undefined)
			value = newValue;
		if (newMuted !== undefined)
			muted = newMuted;
		shown = true;
		hideTimer.restart();
	}

	visible: shown || card.opacity > 0
	color: "transparent"
	exclusiveZone: 0

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell"

	screen: Panels.screen

	anchors {
		top: true
		left: true
		right: true
	}
	margins.top: Theme.panelTop

	implicitHeight: 84

	Timer {
		id: hideTimer
		interval: 1500
		onTriggered: win.shown = false
	}

	Rectangle {
		id: card
		anchors.centerIn: parent
		width: 380
		implicitHeight: 68
		opacity: win.shown ? 1 : 0

		Behavior on opacity {
			NumberAnimation { duration: Theme.animFast }
		}
		color: Theme.glass(Theme.bgCard)
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingElement

		Row {
			anchors.fill: parent
			anchors.margins: 14
			spacing: Theme.paddingItem

			LineIcon {
				width: 36
				anchors.verticalCenter: parent.verticalCenter
				name: win.icon
				size: 26
				color: win.muted ? Theme.textDim : Theme.accentBlue
			}

			Item {
				width: parent.width - 36 - Theme.paddingItem
				height: parent.height

				StyledText {
					anchors.fill: parent
					horizontalAlignment: Text.AlignHCenter
					verticalAlignment: Text.AlignVCenter
					text: win.kind === "mic" ? (win.muted ? "Muted" : "On") : win.value + "%"
					mono: true
					font.pixelSize: Theme.fontSizeSmall
					font.bold: true
				}

				Rectangle {
					anchors.bottom: parent.bottom
					anchors.horizontalCenter: parent.horizontalCenter
					width: parent.width - 24
					height: 6
					radius: Theme.roundingSubtle
					color: Theme.bgHover
					visible: win.kind !== "mic"

					Rectangle {
						anchors.left: parent.left
						anchors.top: parent.top
						anchors.bottom: parent.bottom
						width: parent.width * Math.min(100, Math.max(0, win.value)) / 100
						radius: Theme.roundingSubtle
						color: win.muted ? Theme.textDim : Theme.accentBlue
					}
				}
			}
		}
	}

	// Whatever changed the volume: keys, Actions, another mixer. A node
	// that is not ready yet is only filling in its values, not changing.
	Connections {
		target: SystemStatus.sink?.audio ?? null
		function onVolumeChanged() {
			win.showVolume();
		}
		function onMutedChanged() {
			win.showVolume();
		}
	}

	Connections {
		target: SystemStatus.source?.audio ?? null
		function onMutedChanged() {
			if (SystemStatus.source.ready)
				win.show("mic", undefined, SystemStatus.source.audio.muted);
		}
	}

	function showVolume(): void {
		if (SystemStatus.volumeReady)
			win.show("volume", SystemStatus.volume, SystemStatus.muted);
	}

	// The brightness keys and power-save report the level they set.
	IpcHandler {
		target: "osd"

		function brightness(newValue: int): void {
			SystemStatus.brightness = newValue;
			win.show("brightness", newValue);
		}
	}
}
