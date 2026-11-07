import ".."
import "../widgets"
import Quickshell
import Quickshell.Wayland
import QtQuick

// What just changed, a line in the middle of the bar. It opens from there and takes the
// timer's place for the moment. Over a fullscreen window there is no bar: it comes on glass.
PanelWindow {
	id: win

	property string kind: ""
	property int value: 0
	property bool muted: false
	property bool shown: false
	property real revealed: 0
	// A fresh window's first frame comes late: the growth waits for it, or it starts a third grown.
	property bool drawn: false
	readonly property bool open: shown && drawn

	readonly property string icon: kind === "brightness" ? "sun"
		: kind === "mic" ? (muted ? "mic-off" : "mic")
		: kind === "wallpaper" ? "image"
		: kind === "timer" ? "timer"
		: Audio.icon
	readonly property color tone: muted ? Theme.textDim : Theme.accentBlue

	readonly property string wallpaperName: Wallpaper.path.replace(/^.*\//, "").replace(/\.[^.]*$/, "")

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
	onVisibleChanged: {
		if (!visible)
			drawn = false;
	}
	// In as the drawers come in, out as the bar's pills go.
	onOpenChanged: {
		reveal.stop();
		reveal.to = open ? 1 : 0;
		reveal.easing.type = open ? Easing.BezierSpline : Easing.OutCubic;
		reveal.start();
	}
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

	NumberAnimation {
		id: reveal
		target: win
		property: "revealed"
		duration: Theme.animNormal
		easing.bezierCurve: Theme.easeOutQuint
	}

	Connections {
		target: face.Window.window
		enabled: win.visible && !win.drawn
		function onFrameSwapped() {
			win.drawn = true;
		}
	}

	Timer {
		id: hideTimer
		interval: win.kind === "timer" ? 3000 : 1200
		onTriggered: win.shown = false
	}

	Rectangle {
		id: face
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

			Level {
				anchors.verticalCenter: parent.verticalCenter
				visible: win.kind === "volume" || win.kind === "brightness" || win.kind === "timer"
				value: win.kind === "timer" ? Modes.timerFraction : win.value / 100
				fill: win.tone
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
				visible: win.kind === "timer"
				text: Modes.timerText(Modes.timerLeft)
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

	// Over a fullscreen window there is no bar to count on: the timer comes up as it starts
	// and with a minute to go.
	Connections {
		target: Modes
		function onTimerMoment() {
			if (Hypr.fullscreenOn(Panels.screen))
				win.show("timer");
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
