import ".."
import "../widgets"
import Quickshell
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
		: kind === "wallpaper" ? "image"
		: Audio.icon

	// The wallpaper's name, and the folder SUPER + P goes through.
	readonly property string home: Quickshell.env("HOME")
	readonly property string wallpaperName: Wallpaper.path.replace(/^.*\//, "").replace(/\.[^.]*$/, "")
	readonly property string wallpaperDir: {
		var dir = Wallpaper.path.replace(/\/[^/]*$/, "");
		var shown = dir.startsWith(home + "/") ? "~" + dir.slice(home.length) : dir;
		// One of the desktop's own, which SUPER + P goes through with the user's.
		return dir === home + "/.config/hypr/wallpapers" ? "Built in · add yours to ~/Pictures/Wallpapers" : shown;
	}

	// Actions has sliders for both, which show the change already.
	function show(newKind, newValue, newMuted) {
		if ((newKind === "volume" || newKind === "brightness") && Panels.active === "actions")
			return;
		// Where it appears stays put while it is up and fading.
		if (!shown)
			screen = Panels.screen;
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
					visible: win.kind !== "wallpaper"
					text: win.kind === "mic" ? (win.muted ? "Muted" : "On") : win.value + "%"
					mono: true
					font.pixelSize: Theme.fontSizeSmall
					font.bold: true
				}

				Column {
					anchors.verticalCenter: parent.verticalCenter
					width: parent.width
					visible: win.kind === "wallpaper"
					spacing: 2

					StyledText {
						width: parent.width
						horizontalAlignment: Text.AlignHCenter
						elide: Text.ElideMiddle
						textFormat: Text.PlainText
						text: win.wallpaperName
						font.bold: true
					}

					StyledText {
						width: parent.width
						horizontalAlignment: Text.AlignHCenter
						elide: Text.ElideMiddle
						textFormat: Text.PlainText
						text: win.wallpaperDir
						mono: true
						font.pixelSize: Theme.fontSizeSmall
						color: Theme.textDim
					}
				}

				Rectangle {
					anchors.bottom: parent.bottom
					anchors.horizontalCenter: parent.horizontalCenter
					width: parent.width - 24
					height: 6
					radius: Theme.roundingSubtle
					color: Theme.bgHover
					visible: win.kind !== "mic" && win.kind !== "wallpaper"

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
		target: Audio.sink?.audio ?? null
		function onVolumeChanged() {
			win.showVolume();
		}
		function onMutedChanged() {
			win.showVolume();
		}
	}

	Connections {
		target: Audio.source?.audio ?? null
		function onMutedChanged() {
			if (Audio.source.ready)
				win.show("mic", undefined, Audio.source.audio.muted);
		}
	}

	function showVolume(): void {
		if (Audio.ready)
			win.show("volume", Audio.volume, Audio.muted);
	}

	Connections {
		target: Wallpaper
		function onSwitched() {
			win.show("wallpaper");
		}
	}

	// The brightness keys and power-save.
	Connections {
		target: Brightness
		function onAdjusted() {
			win.show("brightness", Brightness.percent);
		}
	}
}
