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
		: (muted ? "volume-x" : value <= 1 ? "volume" : value <= 50 ? "volume-1" : "volume-2")

	// Quick actions has sliders for both, which show the change already.
	function show(newKind, newValue, newMuted) {
		if ((newKind === "volume" || newKind === "brightness") && Panels.active === "quicksettings")
			return;
		// Read before the stop: a fade-out caught halfway leaves the card dim.
		var fading = fadeOut.running;
		fadeOut.stop();
		if (!shown) {
			card.opacity = 0;
			shown = true;
			fadeIn.start();
		} else if (fading) {
			fadeIn.start();
		}
		if (kind !== newKind)
			kind = newKind;
		if (newValue !== undefined && newValue !== null)
			value = newValue;
		if (newMuted !== undefined && newMuted !== null)
			muted = newMuted;
		hideTimer.restart();
	}

	visible: shown || fadeOut.running
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
	margins.top: Theme.notifTopMargin

	implicitHeight: 84

	Timer {
		id: hideTimer
		interval: 1500
		onTriggered: fadeOut.start()
	}

	NumberAnimation {
		id: fadeIn

		target: card
		property: "opacity"
		to: 1
		duration: Theme.animFast
	}

	SequentialAnimation {
		id: fadeOut

		NumberAnimation {
			target: card
			property: "opacity"
			to: 0
			duration: Theme.animFast
		}

		ScriptAction {
			script: {
				win.shown = false;
				card.opacity = 1;
			}
		}
	}

	Rectangle {
		id: card
		anchors.centerIn: parent
		width: 380
		implicitHeight: 68
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

	// Whatever changed the volume: keys, quick settings, another mixer. A node
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
		var sink = SystemStatus.sink;
		if (sink.ready)
			win.show("volume", Math.round(sink.audio.volume * 100), sink.audio.muted);
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
