// Sticky toast popups, top-right above everything (layer-shell overlay).
// Geometry mirrors the old SwayNC setup: 500px wide, 54px below the top
// (clears the bar), 20px from the right (matches Hyprland gaps_out).
// Pops slide in from the right screen edge and slide back out right.
import ".."
import "../widgets"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick

PanelWindow {
	id: win

	// Shown while toasts exist and neither drawer is open; unmap is
	// deferred until the slide-out animation finishes.
	property bool shown: Notifications.toasts.length > 0 && !Notifications.centerOpen && !QuickSettings.panelOpen
	property int slide: Theme.notifWidth + Theme.notifRightMargin

	property var displayToasts: []

	function toSnapshot(t): var {
		if (!t) return null;
		return {
			id: t.id,
			urgency: t.urgency,
			image: t.image || "",
			appIcon: t.appIcon || "",
			appName: t.appName || t.desktopEntry || "",
			summary: t.summary || "",
			body: t.body || "",
			hasInlineReply: Boolean(t.hasInlineReply),
			inlineReplyPlaceholder: t.inlineReplyPlaceholder || "",
			actions: (t.actions || []).map(a => ({ identifier: a.identifier || "", text: a.text || "" })),
			time: Notifications.historyTimeById(t.id) || Date.now()
		};
	}

	function syncToasts(): void {
		if (Notifications.toasts.length > 0) {
			var snaps = [];
			for (var i = 0; i < Notifications.toasts.length; i++) {
				var s = toSnapshot(Notifications.toasts[i]);
				if (s) snaps.push(s);
			}
			displayToasts = snaps;
		}
	}

	Component.onCompleted: syncToasts()

	Connections {
		target: Notifications
		function onToastsChanged(): void {
			win.syncToasts();
		}
	}

	visible: shown || slideOut.running
	color: "transparent"
	exclusiveZone: 0

	// Global inline-reply keyboard focus state
	QtObject {
		id: replyFocus

		property int count: 0
		readonly property bool active: count > 0

		function bump(delta: int): void {
			count = Math.max(0, count + delta);
			if (count === 0 && win.visible)
				stack.forceActiveFocus();
		}
	}

	mask: Region {
		item: win.shown ? stack : null
	}

	onShownChanged: {
		if (shown) {
			slideOut.stop();
			slideIn.restart();
		} else {
			slideIn.stop();
			slideOut.restart();
		}
	}

	ParallelAnimation {
		id: slideIn

		NumberAnimation {
			target: win
			property: "slide"
			to: 0
			duration: 250
			easing.type: Easing.OutCubic
		}
	}

	SequentialAnimation {
		id: slideOut

		NumberAnimation {
			target: win
			property: "slide"
			to: Theme.notifWidth + Theme.notifRightMargin
			duration: 220
			easing.type: Easing.OutCubic
		}

		ScriptAction {
			script: {
				if (Notifications.toasts.length === 0)
					win.displayToasts = [];
			}
		}
	}

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: replyFocus.active !== true ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
	WlrLayershell.namespace: "quickshell"

	screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

	anchors {
		top: true
		right: true
	}
	margins {
		top: Theme.notifTopMargin
		right: Theme.notifRightMargin - slide
	}

	implicitWidth: Theme.notifWidth
	implicitHeight: stack.implicitHeight

	Column {
		id: stack
		anchors.top: parent.top
		anchors.left: parent.left
		anchors.right: parent.right
		spacing: 8

		Repeater {
			model: win.displayToasts

			delegate: NotificationCard {
				notif: modelData
				isToast: true
				showTime: false
				onActivated: Notifications.activate(notif.id)
				onDismissed: Notifications.dismissById(notif.id)
				onReplyFocusGained: replyFocus.bump(1)
				onReplyFocusLost: replyFocus.bump(-1)
			}
		}
	}
}
