import ".."
import "../widgets"
import Quickshell
import Quickshell.Wayland
import QtQuick

// The newest notifications, under the right end of the bar. The drawers that
// open in the same spot hide them.
PanelWindow {
	id: win

	readonly property bool drawerOpen: Panels.active === "notifications" || Panels.active === "quicksettings" || Panels.active === "weather"
	readonly property bool shown: Notifications.toasts.count > 0 && !drawerOpen
	readonly property int offscreen: Theme.notifWidth + Theme.notifRightMargin
	property int slide: offscreen
	// A reply field has the keyboard.
	property bool replying: false

	visible: shown || slideOut.running
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: replying ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell"

	screen: Panels.screen

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	mask: Region {
		item: win.shown ? stack : null
	}

	Binding {
		target: Notifications
		property: "toastsHeld"
		value: win.replying
	}

	// A card that goes with its field focused never reports losing the focus.
	Connections {
		target: Notifications.toasts
		function onRowsRemoved() {
			win.replying = false;
		}
	}

	onShownChanged: {
		slideIn.stop();
		slideOut.stop();
		if (shown)
			slideIn.start();
		else if (drawerOpen)
			// A drawer slides into the same spot: leave at once.
			win.slide = win.offscreen;
		else
			slideOut.start();
	}

	NumberAnimation {
		id: slideIn
		target: win
		property: "slide"
		to: 0
		duration: Theme.animNormal
		easing.type: Easing.BezierSpline
		easing.bezierCurve: Theme.easeOutQuint
	}

	NumberAnimation {
		id: slideOut
		target: win
		property: "slide"
		to: win.offscreen
		duration: Theme.animNormal
		easing.type: Easing.InCubic
	}

	ListView {
		id: stack
		x: win.width - width - Theme.notifRightMargin + win.slide
		y: Theme.notifTopMargin
		width: Theme.notifWidth
		height: contentHeight
		interactive: false
		spacing: 8
		model: Notifications.toasts

		delegate: NotificationCard {
			width: stack.width
			isToast: true
			onActivated: Notifications.activate(nid)
			onDismissed: Notifications.dismiss(nid)
			onReplyFocused: focused => win.replying = focused
		}

		add: Transition {
			NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animNormal; easing.type: Easing.OutCubic }
			NumberAnimation { property: "x"; from: 60; to: 0; duration: Theme.animNormal; easing.type: Easing.OutCubic }
		}
		remove: Transition {
			NumberAnimation { property: "opacity"; to: 0; duration: Theme.animNormal; easing.type: Easing.OutCubic }
			NumberAnimation { property: "x"; to: 60; duration: Theme.animNormal; easing.type: Easing.OutCubic }
		}
		displaced: Transition {
			NumberAnimation { property: "y"; duration: Theme.animNormal; easing.type: Easing.OutCubic }
		}
	}
}
