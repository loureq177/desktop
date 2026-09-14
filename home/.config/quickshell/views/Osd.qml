// OSD overlay: replaces SwayOSD. Shows volume / microphone / brightness
// state near the top center, fed by scripts via IPC:
//   qs ipc call osd volume <0-100> [muted]
//   qs ipc call osd brightness <0-100>
//   qs ipc call osd mic <muted>
// Fades in and out instead of popping; overlapping updates (held keys) just
// restart the hide timer, and re-shows mid-fade animate smoothly back up.
import ".."
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
	id: win

	property string kind: "" // volume | brightness | mic
	property int value: 0
	property bool muted: false
	// Surface unmap is deferred through `shown` so hides can fade out first.
	property bool shown: false

	readonly property string icon: kind === "brightness" ? "󰃟"
		: kind === "mic" ? (muted ? "󰍭" : "󰍬")
		: (muted ? "󰝟" : value === 0 ? "󰕿" : value <= 50 ? "󰖀" : "󰕾")

	// Overlapping updates restart the hide timer; values update in place.
	// Fades the card, not the window: QsWindow has no `opacity`.
	function show(newKind, newValue, newMuted) {
		fadeOut.stop();
		if (!win.visible) {
			card.opacity = 0;
			shown = true;
			fadeIn.start();
		} else if (fadeOut.running) {
			fadeIn.start(); // animate back up from the current opacity
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

	screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

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

	readonly property alias card: card

	NumberAnimation {
		id: fadeIn

		target: card
		property: "opacity"
		to: 1
		duration: 140
	}

	SequentialAnimation {
		id: fadeOut

		NumberAnimation {
			target: card
			property: "opacity"
			to: 0
			duration: 140
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
		color: Theme.overlayColor
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingElement

		Row {
			anchors.fill: parent
			anchors.margins: 14
			spacing: Theme.paddingItem

			Text {
				width: 36
				anchors.verticalCenter: parent.verticalCenter
				horizontalAlignment: Text.AlignHCenter
				text: win.icon
				font.family: Theme.fontFamily
				font.pixelSize: 26
				color: win.muted ? Theme.textDim : Theme.accentBlue
			}

			Item {
				width: parent.width - 36 - Theme.paddingItem
				height: parent.height

				Text {
					anchors.fill: parent
					horizontalAlignment: Text.AlignHCenter
					verticalAlignment: Text.AlignVCenter
					// Mic has no level: show state instead of a bar.
					text: win.kind === "mic" ? (win.muted ? "Muted" : "On") : win.value + "%"
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeSmall
					font.bold: true
					color: Theme.textMain
				}

				Rectangle {
					anchors.bottom: parent.bottom
					anchors.horizontalCenter: parent.horizontalCenter
					width: parent.width - 24
					height: 6
					radius: 3
					color: Theme.bgHover
					visible: win.kind !== "mic"

					Rectangle {
						anchors.left: parent.left
						anchors.top: parent.top
						anchors.bottom: parent.bottom
						width: parent.width * Math.min(100, Math.max(0, win.value)) / 100
						radius: 3
						color: win.muted ? Theme.textDim : Theme.accentBlue
					}
				}
			}
		}
	}

	IpcHandler {
		target: "osd"

		function volume(newValue: int, isMuted: bool): void {
			win.show("volume", newValue, isMuted);
		}
		function brightness(newValue: int): void {
			win.show("brightness", newValue);
		}
		function mic(isMuted: bool): void {
			win.show("mic", undefined, isMuted);
		}
	}
}
