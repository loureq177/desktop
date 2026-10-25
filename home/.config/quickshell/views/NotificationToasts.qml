import ".."
import "../widgets"
import Quickshell
import Quickshell.Wayland
import QtQuick

// The newest notifications, under the right end of the bar, while no panel
// is open: a panel that opens puts them away for good.
PanelWindow {
	id: win

	readonly property bool shown: Notifications.toasts.count > 0 && Panels.active === ""
	readonly property int offscreen: Theme.drawerWidth + Theme.panelMargin
	property int slide: offscreen

	visible: shown || slideOut.running
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0

	WlrLayershell.layer: WlrLayer.Overlay
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

	Connections {
		target: Panels
		function onActiveChanged() {
			if (Panels.active !== "")
				Notifications.toasts.clear();
		}
	}

	onShownChanged: {
		slideIn.stop();
		slideOut.stop();
		if (shown)
			slideIn.start();
		else if (Panels.active !== "")
			// A panel opens, maybe a drawer into the same spot: leave at once.
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
		x: win.width - width - Theme.panelMargin + win.slide
		y: Theme.panelTop
		width: Theme.drawerWidth
		height: contentHeight
		interactive: false
		spacing: 8
		model: Notifications.toasts

		delegate: NotificationCard {
			width: stack.width
			isToast: true
			onActivated: Notifications.activate(nid)
			onDismissed: Notifications.dismiss(nid)
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
