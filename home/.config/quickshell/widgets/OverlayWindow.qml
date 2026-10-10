import ".."
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
	id: root

	property bool shown: false
	property bool instantHide: false
	property bool grabFocus: false
	property bool dismissOnEsc: true
	property int layer: WlrLayer.Overlay
	property int keyboardFocusMode: WlrKeyboardFocus.Exclusive
	property string namespace: "quickshell"
	property color backdropColor: Theme.backdropColor
	property real backdropOpacity: 0.0

	property Animation enterAnimation
	property Animation exitAnimation
	readonly property bool animating: (enterAnimation?.running ?? false) || (exitAnimation?.running ?? false)

	signal opened()
	signal dismissed()
	signal dismissRequested()
	signal fullyClosed()
	signal snapped()

	function close() {
		root.shown = false;
	}

	visible: shown || (exitAnimation?.running ?? false)
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
			enterAnimation?.restart();
			root.opened();
		} else if (root.instantHide) {
			enterAnimation?.stop();
			exitAnimation?.stop();
			root.backdropOpacity = 0.0;
			root.snapped();
			root.fullyClosed();
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

	HyprlandFocusGrab {
		active: root.shown && root.grabFocus
		windows: [ root ]
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
			enabled: root.shown
			onPressed: root.dismissRequested()
		}
	}
}
