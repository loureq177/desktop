import ".."
import "Pointer.js" as Pointer
import Quickshell.Wayland
import QtQuick

// The launcher's card over a dim: it has the keyboard; Esc or a click on the dim
// dismisses it.
StandbyWindow {
	id: root

	property bool shown: false
	// 0 hidden, 1 on screen.
	property real progress: 0
	readonly property bool animating: anim.running
	default property alias content: stage.data

	signal dismissRequested()

	// Bound to the progress, not to `shown`: the window stays full size until the
	// way out has run, and takes it at once on the way in.
	open: shown || progress > 0

	WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell"

	// The screen is taken when it opens and kept through the way out: the
	// focus moving on meanwhile must not carry the fading card along.
	onShownChanged: {
		if (shown) {
			screen = Panels.screen;
			Pointer.hold(Theme.animNormal);
		}
		anim.stop();
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
		width: root.fullWidth
		height: root.fullHeight
		color: Theme.backdropColor
		opacity: root.progress

		MouseArea {
			anchors.fill: parent
			enabled: root.shown
			onPressed: root.dismissRequested()
		}
	}

	FocusScope {
		id: stage
		width: root.fullWidth
		height: root.fullHeight
		visible: root.open
		focus: true
		opacity: root.progress

		Keys.onEscapePressed: root.dismissRequested()
	}
}
