import ".."
import Quickshell
import Quickshell.Wayland
import QtQuick

// A card in the middle of the screen over a dim: the launcher, the polkit
// dialog. It has the keyboard while shown; Esc or a click on the dim asks to
// dismiss it. The card fades in (and grows, scaled by `progress` itself), and
// after Panels.closeInstant it is gone in the same frame.
PanelWindow {
	id: root

	property bool shown: false
	property bool dismissOnClick: true
	// 0 hidden, 1 on screen.
	property real progress: 0
	readonly property bool animating: anim.running
	default property alias content: stage.data

	signal dismissRequested()

	// Bound to the progress, not to `shown`: the window stays mapped until the
	// way out has run, and maps at once on the way in.
	visible: shown || progress > 0
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell"

	screen: Panels.screen

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	onShownChanged: {
		anim.stop();
		if (!shown && Panels.instant) {
			progress = 0;
			return;
		}
		anim.to = shown ? 1 : 0;
		anim.duration = shown ? Theme.animNormal : Theme.animFast;
		anim.easing.type = shown ? Easing.BezierSpline : Easing.InCubic;
		anim.start();
	}

	NumberAnimation {
		id: anim
		target: root
		property: "progress"
		easing.bezierCurve: Theme.easeOutQuint
	}

	Rectangle {
		anchors.fill: parent
		color: Theme.backdropColor
		opacity: root.progress

		MouseArea {
			anchors.fill: parent
			enabled: root.shown && root.dismissOnClick
			onPressed: root.dismissRequested()
		}
	}

	FocusScope {
		id: stage
		anchors.fill: parent
		focus: true
		opacity: root.progress

		Keys.onEscapePressed: root.dismissRequested()
	}
}
