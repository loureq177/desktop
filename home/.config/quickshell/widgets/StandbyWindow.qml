import ".."
import Quickshell
import Quickshell.Wayland
import QtQuick

// A window of the panels. Closed, it stays mapped as one clear pixel: opening only resizes it,
// 10 ms against 140 to make a surface. Over a fullscreen window it goes, as the bar does.
PanelWindow {
	id: root

	// What it holds is on screen, or on its way in or out.
	property bool open: false
	// For the contents: they keep their layout while the window is a pixel.
	readonly property int fullWidth: screen?.width ?? 0
	readonly property int fullHeight: screen?.height ?? 0

	// Panels.screen, where it waits: its own `screen` would loop, as mapping sets that.
	readonly property bool covered: Hypr.fullscreenOn(Panels.screen)
	visible: open || !covered
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0
	implicitWidth: 1
	implicitHeight: 1
	mask: open ? null : clickThrough

	screen: Panels.screen

	anchors {
		top: true
		left: true
		bottom: root.open
		right: root.open
	}

	Region {
		id: clickThrough
	}

	// Closed, it waits on the monitor with the focus.
	onOpenChanged: {
		if (!open)
			screen = Panels.screen;
	}

	Connections {
		target: Panels
		function onScreenChanged() {
			if (!root.open)
				root.screen = Panels.screen;
		}
	}
}
