import ".."
import "../widgets"
import Quickshell
import Quickshell.Wayland
import QtQuick

// What just changed, a line in the middle of the bar. It opens from there and takes that
// bar's sun line for the moment. Over a fullscreen window there is no bar: it comes on glass.
PanelWindow {
	id: win

	property string kind: ""
	property int value: 0
	property bool muted: false
	property bool shown: false
	property real revealed: shown ? 1 : 0

	readonly property string icon: kind === "brightness" ? "sun"
		: kind === "mic" ? (muted ? "mic-off" : "mic")
		: kind === "wallpaper" ? "image"
		: Audio.icon
	readonly property color tone: muted ? Theme.textDim : Theme.accentBlue

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
		muted = newMuted === true;
		shown = true;
		hideTimer.restart();
	}

	onShownChanged: Bars.osdScreen = shown ? (screen?.name ?? "") : ""

	visible: shown || revealed > 0
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0
	// It only shows: clicks go through to what is under it.
	mask: Region {}

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell"

	screen: Panels.screen

	anchors {
		top: true
		left: true
		right: true
	}
	margins.top: Theme.barMarginY

	implicitHeight: Theme.barHeight

	Behavior on revealed {
		NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
	}

	Timer {
		id: hideTimer
		interval: 1200
		onTriggered: win.shown = false
	}

	Rectangle {
		anchors.centerIn: parent
		width: (line.width + 2 * Theme.paddingCard) * win.revealed
		height: parent.height
		opacity: win.revealed
		clip: win.revealed < 1
		color: Hypr.fullscreenOn(win.screen) ? Theme.glass(Theme.bgCard) : "transparent"
		radius: Theme.roundingElement

		Row {
			id: line
			anchors.centerIn: parent
			height: parent.height
			spacing: 10
			layer.enabled: true
			layer.effect: Halo {}

			LineIcon {
				anchors.verticalCenter: parent.verticalCenter
				name: win.icon
				color: win.tone
			}

			Rectangle {
				anchors.verticalCenter: parent.verticalCenter
				visible: win.kind === "volume" || win.kind === "brightness"
				width: 180
				height: 4
				radius: 2
				color: Theme.alpha(Theme.textMain, 0.25)

				Rectangle {
					width: parent.width * Math.min(100, Math.max(0, win.value)) / 100
					height: parent.height
					radius: parent.radius
					color: win.tone

					Behavior on width {
						NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
					}
				}
			}

			// A fixed room: the line does not shift between 9% and 10%.
			StyledText {
				anchors.verticalCenter: parent.verticalCenter
				visible: win.kind === "volume" || win.kind === "brightness"
				width: 38
				horizontalAlignment: Text.AlignRight
				text: win.value + "%"
				mono: true
				font.bold: true
				font.pixelSize: Theme.fontSizeBar
			}

			StyledText {
				anchors.verticalCenter: parent.verticalCenter
				visible: win.kind === "mic"
				text: win.muted ? "Muted" : "On"
				font.bold: true
				font.pixelSize: Theme.fontSizeBar
			}

			StyledText {
				anchors.verticalCenter: parent.verticalCenter
				visible: win.kind === "wallpaper"
				width: Math.min(implicitWidth, 300)
				elide: Text.ElideMiddle
				textFormat: Text.PlainText
				text: win.wallpaperName
				font.bold: true
				font.pixelSize: Theme.fontSizeBar
			}

			StyledText {
				anchors.verticalCenter: parent.verticalCenter
				visible: win.kind === "wallpaper"
				width: Math.min(implicitWidth, 360)
				elide: Text.ElideMiddle
				textFormat: Text.PlainText
				text: win.wallpaperDir
				mono: true
				font.pixelSize: Theme.fontSizeSmall
				color: Theme.textDim
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

	// The brightness keys.
	Connections {
		target: Brightness
		function onAdjusted() {
			win.show("brightness", Brightness.percent);
		}
	}
}
