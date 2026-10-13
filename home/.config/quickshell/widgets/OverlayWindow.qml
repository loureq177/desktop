import ".."
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
	id: root

	property bool shown: false
	property bool instantHide: false
	// Closing because another overlay takes this one's place.
	property bool handoff: false
	property bool grabFocus: false
	property bool dismissOnEsc: true
	property bool dismissOnClick: true
	property int layer: WlrLayer.Overlay
	property int keyboardFocusMode: WlrKeyboardFocus.Exclusive
	property string namespace: "quickshell"
	property color backdropColor: Theme.backdropColor
	property real backdropOpacity: 0.0

	property Animation enterAnimation
	property Animation exitAnimation
	// Played instead of exitAnimation on a handoff; without one the regular exit runs.
	property Animation handoffAnimation
	readonly property bool leaving: (exitAnimation?.running ?? false) || (handoffAnimation?.running ?? false)
	readonly property bool animating: (enterAnimation?.running ?? false) || leaving

	signal opened()
	signal dismissed()
	signal dismissRequested()
	signal fullyClosed()
	signal snapped()

	function close() {
		root.shown = false;
	}

	visible: shown || leaving
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0

	WlrLayershell.layer: root.layer
	WlrLayershell.keyboardFocus: shown ? keyboardFocusMode : WlrKeyboardFocus.None
	WlrLayershell.namespace: root.namespace

	screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	onShownChanged: {
		if (shown) {
			exitAnimation?.stop();
			handoffAnimation?.stop();
			enterAnimation?.restart();
			root.opened();
		} else if (root.instantHide) {
			enterAnimation?.stop();
			exitAnimation?.stop();
			root.backdropOpacity = 0.0;
			root.snapped();
			root.fullyClosed();
		} else if (root.handoff && root.handoffAnimation) {
			enterAnimation?.stop();
			handoffAnimation.restart();
		} else {
			enterAnimation?.stop();
			exitAnimation?.restart();
		}
	}

	Connections {
		target: root.exitAnimation
		function onRunningChanged() {
			if (!root.exitAnimation.running && !root.shown)
				root.fullyClosed();
		}
	}

	Connections {
		target: root.handoffAnimation
		function onRunningChanged() {
			if (!root.handoffAnimation.running && !root.shown)
				root.fullyClosed();
		}
	}

	HyprlandFocusGrab {
		active: root.shown && root.grabFocus
		windows: [ root ].concat(Bars.windows)
		onCleared: root.dismissed()
	}

	Shortcut {
		sequences: ["Esc"]
		enabled: root.visible && root.dismissOnEsc
		onActivated: root.dismissRequested()
	}

	Rectangle {
		id: backdrop
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
