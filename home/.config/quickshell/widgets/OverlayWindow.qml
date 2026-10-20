import ".."
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

// A full-screen layer around one card. With style "fade" the card fades and
// scales in over the backdrop; with "slide" it slides in from offscreenSlide
// pixels away, takes the keyboard only on demand and closes when another
// window is clicked.
PanelWindow {
	id: root

	// Its name in Panels. A window that is not a panel (polkit) sets `shown`.
	property string panel: ""
	property bool shown: panel !== "" && Panels.active === panel
	property string style: "fade"
	property Item card
	// Closing because another drawer takes this one's place: the card fades
	// out where it is instead of sliding across the newcomer.
	property bool handoff: false
	// Swapping with a window of the same size and place (the centred ones):
	// the newcomer is there at once (swapIn) and the one leaving stays a few
	// frames without its dim (swapOut), so no frame shows a half-transparent
	// card, which Hyprland would not blur, or two dims on top of each other.
	property bool swapIn: false
	property bool swapOut: false
	property bool dismissOnEsc: true
	property bool dismissOnClick: true
	property color backdropColor: Theme.backdropColor
	property real backdropOpacity: 0.0
	property real enterScale: 0.96
	property real exitScale: 0.97
	property int offscreenSlide: 0
	property int slide: offscreenSlide

	readonly property bool sliding: style === "slide"
	readonly property Animation enterAnimation: sliding ? slideIn : fadeIn
	readonly property Animation exitAnimation: sliding ? slideOut : fadeOut
	readonly property bool leaving: exitAnimation.running || handoffOut.running || swapOutTimer.running
	readonly property bool animating: enterAnimation.running || leaving

	// A panel gets the mode Panels opened it on, also when reopened on another.
	signal opened(string mode)
	signal dismissRequested()
	signal fullyClosed()

	// Set by hand, not bound to `shown || leaving`: that binding could run
	// before onShownChanged starts the way out, unmapping the window for a
	// frame and mapping it again, which shows as a blink.
	property bool mapped: false
	visible: mapped
	onFullyClosed: mapped = false
	Component.onCompleted: mapped = shown
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0

	WlrLayershell.layer: sliding ? WlrLayer.Top : WlrLayer.Overlay
	WlrLayershell.keyboardFocus: !shown ? WlrKeyboardFocus.None : sliding ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive
	WlrLayershell.namespace: "quickshell"

	screen: Panels.screen

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	onOffscreenSlideChanged: {
		if (!shown && !animating)
			slide = offscreenSlide;
	}

	onShownChanged: {
		if (shown) {
			mapped = true;
			exitAnimation.stop();
			handoffOut.stop();
			swapOutTimer.stop();
			if (swapIn) {
				enterAnimation.stop();
				backdropOpacity = 1.0;
				card.opacity = 1.0;
				card.scale = 1.0;
				slide = 0;
			} else {
				enterAnimation.restart();
			}
			if (panel === "")
				root.opened("");
		} else if (Panels.instant && panel !== "") {
			enterAnimation.stop();
			backdropOpacity = 0.0;
			slide = offscreenSlide;
			root.fullyClosed();
		} else if (handoff && swapOut) {
			enterAnimation.stop();
			backdropOpacity = 0.0;
			swapOutTimer.restart();
		} else if (handoff) {
			enterAnimation.stop();
			handoffOut.restart();
		} else {
			enterAnimation.stop();
			exitAnimation.restart();
		}
	}

	Connections {
		target: Panels
		enabled: root.panel !== ""
		function onOpened(name, mode) {
			if (name === root.panel)
				root.opened(mode);
		}
	}

	ParallelAnimation {
		id: fadeIn
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			from: 0.0
			to: 1.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}
		NumberAnimation {
			target: root.card
			property: "opacity"
			from: 0.0
			to: 1.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}
		NumberAnimation {
			target: root.card
			property: "scale"
			from: root.enterScale
			to: 1.0
			duration: Theme.animNormal
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
	}

	ParallelAnimation {
		id: fadeOut
		onFinished: {
			if (!root.shown)
				root.fullyClosed();
		}
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			to: 0.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}
		NumberAnimation {
			target: root.card
			property: "opacity"
			to: 0.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}
		NumberAnimation {
			target: root.card
			property: "scale"
			to: root.exitScale
			duration: Theme.animFast
			easing.type: Easing.InCubic
		}
	}

	ParallelAnimation {
		id: slideIn
		NumberAnimation {
			target: root
			property: "slide"
			from: root.slide
			to: 0
			duration: Theme.animNormal
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			from: root.backdropOpacity
			to: 1.0
			duration: Theme.animNormal
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
	}

	ParallelAnimation {
		id: slideOut
		onFinished: {
			if (!root.shown)
				root.fullyClosed();
		}
		NumberAnimation {
			target: root
			property: "slide"
			from: root.slide
			to: root.offscreenSlide
			duration: Theme.animNormal
			easing.type: Easing.InCubic
		}
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			from: root.backdropOpacity
			to: 0.0
			duration: Theme.animNormal
			easing.type: Easing.InCubic
		}
	}

	// Long enough for the newcomer to map and draw its first frame.
	Timer {
		id: swapOutTimer
		interval: 80
		onTriggered: {
			if (!root.shown)
				root.fullyClosed();
		}
	}

	// The backdrop mirrors the newcomer's fade-in, so the dim stays level.
	ParallelAnimation {
		id: handoffOut
		onFinished: {
			root.card.opacity = 1.0;
			root.slide = root.offscreenSlide;
			if (!root.shown)
				root.fullyClosed();
		}
		NumberAnimation {
			target: root.card
			property: "opacity"
			to: 0.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			from: root.backdropOpacity
			to: 0.0
			duration: Theme.animNormal
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
	}

	HyprlandFocusGrab {
		active: root.shown && root.sliding
		windows: [root].concat(Bars.windows)
		onCleared: root.dismissRequested()
	}

	Shortcut {
		sequences: ["Esc"]
		enabled: root.visible && root.dismissOnEsc
		onActivated: root.dismissRequested()
	}

	Rectangle {
		anchors.fill: parent
		color: root.backdropColor
		opacity: root.backdropOpacity

		MouseArea {
			anchors.fill: parent
			enabled: root.shown && root.dismissOnClick
			onPressed: root.dismissRequested()
		}
	}
}
