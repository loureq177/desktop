import ".."
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
	id: root

	property bool shown: false
	property int cardWidth: Theme.notifWidth
	property int cardHeight: Math.min(680, root.height - Theme.notifTopMargin - 20)
	signal opened()
	signal dismissed()
	signal drawerClosed()

	property int slide: root.cardWidth + Theme.notifRightMargin
	property bool fromLeft: false
	property real backdropOpacity: 0.0
	property bool instantHide: false

	default property alias body: bodySlot.data

	visible: shown || slideOut.running
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0

	onShownChanged: {
		if (shown) {
			slideOut.stop();
			slideIn.restart();
			opened();
		} else if (root.instantHide) {
			slideIn.stop();
			slideOut.stop();
			root.slide = root.cardWidth + Theme.notifRightMargin;
			root.backdropOpacity = 0.0;
			root.drawerClosed();
		} else {
			slideIn.stop();
			slideOut.restart();
		}
	}

	ParallelAnimation {
		id: slideIn

		NumberAnimation {
			target: root
			property: "slide"
			from: root.slide
			to: 0
			duration: Theme.animSmooth
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			from: 0.0
			to: 1.0
			duration: Theme.animSmooth
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
	}

	ParallelAnimation {
		id: slideOut

		onRunningChanged: {
			if (!running && !root.shown) {
				root.drawerClosed();
			}
		}

		NumberAnimation {
			target: root
			property: "slide"
			from: root.slide
			to: root.cardWidth + Theme.notifRightMargin
			duration: Theme.animNormal
			easing.type: Easing.InCubic
		}
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			from: 1.0
			to: 0.0
			duration: Theme.animNormal
			easing.type: Easing.InCubic
		}
	}

	property int keyboardFocusMode: WlrKeyboardFocus.OnDemand

	WlrLayershell.layer: WlrLayer.Top
	WlrLayershell.keyboardFocus: shown ? keyboardFocusMode : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell"

	HyprlandFocusGrab {
		active: root.shown
		windows: [ root ]
		onCleared: root.dismissed()
	}

	screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	property bool dismissOnEsc: true

	Behavior on cardHeight {
		NumberAnimation {
			duration: Theme.animNormal
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
	}

	Shortcut {
		sequences: ["Esc"]
		enabled: root.visible && root.dismissOnEsc
		onActivated: root.dismissed()
	}

	Rectangle {
		id: backdrop
		anchors.fill: parent
		color: Theme.backdropColor
		opacity: root.backdropOpacity

		MouseArea {
			anchors.fill: parent
			enabled: root.shown
			onPressed: {
				root.dismissed();
			}
		}
	}

	Rectangle {
		id: card

		x: root.fromLeft ? Theme.notifRightMargin - root.slide : parent.width - width - Theme.notifRightMargin + root.slide
		y: Theme.notifTopMargin
		width: root.cardWidth
		height: root.cardHeight
		color: Theme.bgCard
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingWindow
		clip: true

		Keys.onEscapePressed: event => {
			if (root.dismissOnEsc) {
				root.dismissed();
				event.accepted = true;
			}
		}

		MouseArea {
			anchors.fill: parent
			enabled: root.shown
			hoverEnabled: true
		}

		Item {
			id: bodySlot
			anchors.fill: parent
			anchors.margins: Theme.paddingCard
		}
	}
}
