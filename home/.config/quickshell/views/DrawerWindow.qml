import ".."
import "../widgets"
import Quickshell
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

	// The keyboard whatever the pointer rests on, as the launcher: opened from the bar,
	// the bar under the pointer took the keys and Esc did nothing.
	WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell"

	// Taken when a drawer opens, kept while it leaves: the focus moving to
	// another monitor closes it, and it must finish where it started.
	onShownChanged: {
		if (shown)
			screen = Panels.screen;
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
}
