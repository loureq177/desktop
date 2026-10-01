// Shared chrome for the top-right slide-in drawers (notification center,
// quick settings): full-screen window, dim backdrop (click/Esc dismisses),
// card geometry, slide animations and deferred unmap until slide-out ends.
//
// Callers bind `shown`, handle `opened` (close the competing drawer,
// refresh polled state) and `dismissed` (close self), and put their body
// in the default slot (already inset by Theme.paddingCard).
import ".."
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
	id: root

	// Controlled by the caller (e.g. Notifications.centerOpen).
	property bool shown: false
	// Fixed card dimensions; callers with dynamic content override them.
	property int cardWidth: Theme.notifWidth
	property int cardHeight: Math.min(680, root.height - Theme.notifTopMargin - 20)
	signal opened()
	signal dismissed()

	// 0 = on screen; width + margin = fully off the right edge.
	property int slide: root.cardWidth + Theme.notifRightMargin
	property real backdropOpacity: 0.0

	default property alias body: bodySlot.data

	visible: shown || slideOut.running
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0

	onShownChanged: {
		if (shown) {
			slideOut.stop();
			slideIn.restart();
			card.forceActiveFocus();
			opened();
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
			from: root.cardWidth + Theme.notifRightMargin
			to: 0
			duration: 250
			easing.type: Easing.OutCubic
		}
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			from: 0.0
			to: 1.0
			duration: 250
			easing.type: Easing.OutCubic
		}
	}

	ParallelAnimation {
		id: slideOut

		NumberAnimation {
			target: root
			property: "slide"
			from: 0
			to: root.cardWidth + Theme.notifRightMargin
			duration: 220
			easing.type: Easing.OutCubic
		}
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			from: 1.0
			to: 0.0
			duration: 220
			easing.type: Easing.OutCubic
		}
	}

	property int keyboardFocusMode: WlrKeyboardFocus.Exclusive

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: shown ? keyboardFocusMode : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell"

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
			duration: 200
			easing.type: Easing.OutCubic
		}
	}

	// ESC dismisses the drawer.
	Shortcut {
		sequences: ["Esc"]
		enabled: root.visible && root.dismissOnEsc
		onActivated: root.dismissed()
	}

	// Full-screen dim backdrop matching Hyprland's special workspace dimming effect (dim_special = 0.20)
	Rectangle {
		id: backdrop
		anchors.fill: parent
		color: Theme.backdropColor
		opacity: root.backdropOpacity

		MouseArea {
			anchors.fill: parent
			enabled: root.shown
			onClicked: root.dismissed()
		}
	}

	Rectangle {
		id: card

		x: parent.width - width - Theme.notifRightMargin + root.slide
		y: Theme.notifTopMargin
		width: root.cardWidth
		height: root.cardHeight
		color: Theme.bgCard
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingWindow
		clip: true
		focus: true

		Keys.onEscapePressed: event => {
			if (root.dismissOnEsc) {
				root.dismissed();
				event.accepted = true;
			}
		}

		// Absorb clicks inside the panel so they don't reach the backdrop.
		MouseArea {
			anchors.fill: parent
			hoverEnabled: true
		}

		Item {
			id: bodySlot
			anchors.fill: parent
			anchors.margins: Theme.paddingCard
		}
	}
}
