import ".."
import Quickshell
import Quickshell.Wayland
import QtQuick

// The dim behind the launcher and the clipboard, one for both: each window
// dimming on its own would blink when they swap, as two surfaces never hand
// over in the same frame. It lies below them and lets every click through.
PanelWindow {
	id: root

	readonly property bool shown: Panels.centered.indexOf(Panels.active) !== -1
	property real level: 0

	visible: shown || level > 0
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell-dim"

	screen: Panels.screen

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	mask: Region {}

	onShownChanged: {
		fade.stop();
		// Gone in the same frame as the window above it (Panels.closeInstant).
		if (!shown && Panels.instant) {
			level = 0;
			return;
		}
		fade.to = shown ? 1 : 0;
		fade.start();
	}

	NumberAnimation {
		id: fade
		target: root
		property: "level"
		duration: Theme.animFast
		easing.type: Easing.OutCubic
	}

	Rectangle {
		anchors.fill: parent
		color: Theme.backdropColor
		opacity: root.level
	}
}
