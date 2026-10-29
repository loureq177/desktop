import ".."
import "../widgets"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

// The drawers under the bar (Actions, notifications, weather) in one window; a
// click elsewhere puts them away.
PanelWindow {
	id: root

	readonly property var drawers: ["actions", "notifications", "weather"]
	readonly property bool shown: drawers.includes(Panels.active)
	readonly property real level: Math.max(actions.progress, notifications.progress, weather.progress)

	visible: shown || level > 0
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0

	WlrLayershell.layer: WlrLayer.Top
	WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell"

	screen: Panels.screen

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

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
		anchors.fill: parent
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
		anchors.fill: parent

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
