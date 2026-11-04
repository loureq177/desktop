import ".."
import "../widgets"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

// The drawers under the bar (Actions, notifications, weather) in one window; a
// click elsewhere puts them away.
StandbyWindow {
	id: root

	readonly property var drawers: ["actions", "notifications", "weather"]
	readonly property bool shown: drawers.includes(Panels.active)
	readonly property real level: Math.max(actions.progress, notifications.progress, weather.progress)

	open: shown || level > 0

	WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell"

	// Taken when a drawer opens, kept while it leaves: the focus moving to
	// another monitor closes it, and it must finish where it started.
	onShownChanged: {
		if (shown)
			screen = Panels.screen;
	}

	HyprlandFocusGrab {
		active: root.shown
		windows: [root].concat(Bars.windows)
		onCleared: Panels.close()
	}

	Rectangle {
		width: root.fullWidth
		height: root.fullHeight
		color: Theme.backdropColor
		opacity: root.level

		MouseArea {
			anchors.fill: parent
			enabled: root.shown
			onPressed: Panels.close()
		}
	}

	Item {
		readonly property var drawers: root.drawers
		width: root.fullWidth
		height: root.fullHeight

		ActionsDrawer {
			id: actions
		}

		NotificationCenter {
			id: notifications
		}

		WeatherView {
			id: weather
		}
	}

	// The bar's corners while a drawer is open: the pointer resting in one stays on this
	// window, which then keeps the keyboard (Hyprland gives it to the layer under the pointer).
	HotCorner {
		present: root.shown
		panel: "launcher"
		mode: "apps"
	}

	HotCorner {
		present: root.shown
		x: root.fullWidth - 1
		panel: "actions"
	}
}
