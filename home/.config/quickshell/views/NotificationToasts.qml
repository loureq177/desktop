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
import QtQml.Models
import QtQuick

PanelWindow {
	id: win

	// Shown while toasts exist and neither drawer is open; unmap is
	// deferred until the slide-out animation finishes.
	property bool shown: Notifications.toasts.length > 0 && !Notifications.centerOpen && !QuickSettings.panelOpen && !Weather.panelOpen
	property int slide: Theme.notifWidth + Theme.notifRightMargin

	// Incremental ListModel (roles: nid, snap, entering): insert/remove emit
	// row signals, so kept cards are never rebuilt (a plain array reassign
	// destroys and recreates every delegate, replaying animations).
	ListModel {
		id: toastModel
	}
	property int lastLiveCount: 0

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

	// Incremental visual sync: kept rows are untouched (delegates survive),
	// new arrivals insert at the top with an entrance animation (only while
	// the window is already open — the window slide covers the first batch),
	// gone rows collapse in place and are swept after their exit animation.
	// Order stays newest-first.
	function syncToasts(): void {
		var live = Notifications.toasts;
		var liveIds = {};
		var i;
		for (i = 0; i < live.length; i++) {
			if (live[i])
				liveIds[String(live[i].id)] = true;
		}
		var have = {};
		for (i = 0; i < toastModel.count; i++)
			have[toastModel.get(i).nid] = true;
		var windowOpen = win.lastLiveCount > 0;
		// Walk oldest-first, inserting missing rows at 0, so the block lands
		// newest-first without touching kept rows.
		for (i = live.length - 1; i >= 0; i--) {
			if (live[i] && !have[String(live[i].id)]) {
				var s = win.toSnapshot(live[i]);
				if (s)
					toastModel.insert(0, { nid: String(s.id), snap: s, entering: windowOpen });
			}
		}
		win.lastLiveCount = live.length;
		var needSweep = false;
		for (i = 0; i < toastModel.count; i++) {
			if (!liveIds[toastModel.get(i).nid]) {
				needSweep = true;
				break;
			}
		}
		if (needSweep)
			sweepTimer.restart();
	}

	Component.onCompleted: syncToasts()

	Connections {
		target: Notifications
		function onToastsChanged(): void {
			win.syncToasts();
		}
	}

	// Drops exit-animated rows once their collapse finished. (The slideOut
	// end handler converges to the same empty state when the window hides.)
	Timer {
		id: sweepTimer
		interval: 280
		onTriggered: {
			var live = Notifications.toasts;
			var ids = {};
			for (var i = 0; i < live.length; i++) {
				if (live[i])
					ids[String(live[i].id)] = true;
			}
			for (var k = toastModel.count - 1; k >= 0; k--) {
				if (!ids[toastModel.get(k).nid])
					toastModel.remove(k);
			}
		}
	}

	visible: shown || slideOut.running
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
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

	// Same slide physics as the SideDrawer drawers (notification center,
	// quick settings): in on Theme.animSmooth/easeOutQuint, out on
	// Theme.animNormal/InCubic. Toasts stay non-modal, so there is no
	// backdrop fade to mirror.
	ParallelAnimation {
		id: slideIn

		NumberAnimation {
			target: win
			property: "slide"
			from: win.slide
			to: 0
			duration: Theme.animSmooth
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
	}

	ParallelAnimation {
		id: slideOut

		onRunningChanged: {
			if (!running && !win.shown && Notifications.toasts.length === 0 && toastModel.count > 0)
				toastModel.clear();
		}

		NumberAnimation {
			target: win
			property: "slide"
			from: win.slide
			to: Theme.notifWidth + Theme.notifRightMargin
			duration: Theme.animNormal
			easing.type: Easing.InCubic
		}
	}

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: replyFocus.active !== true ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
	WlrLayershell.namespace: "quickshell"

	screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

	// Fullscreen like SideDrawer: the stack slides via its own x, so the
	// window geometry never moves and the motion matches the drawers
	// exactly (animating window margins rendered as a linear slide).
	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	Column {
		id: stack
		x: win.width - width - Theme.notifRightMargin + win.slide
		y: Theme.notifTopMargin
		width: Theme.notifWidth
		spacing: 8

		Repeater {
			model: toastModel

			// Per-card wrapper: every toast animates its own entrance
			// (grow + fade + slide) and exit (collapse + fade + slide), so
			// stacked toasts glide instead of popping. `gone` derives from
			// the live toast array (notifying); roles themselves are
			// write-once at insert.
			delegate: Item {
				id: wrap

				required property var snap
				required property bool entering
				property bool entered: false

				readonly property string nid: snap ? String(snap.id) : ""
				readonly property bool gone: {
					var t = Notifications.toasts;
					for (var i = 0; i < t.length; i++) {
						if (t[i] && String(t[i].id) === wrap.nid)
							return false;
					}
					return true;
				}
				// Card exit runs only while the window stays open (mid-stack
				// dismiss/expiry). When the window itself hides, its slide
				// covers the exit and the card must stay whole — otherwise
				// two animations play on top of each other (e.g. SUPER+,).
				readonly property bool cardExit: gone && win.shown

				width: stack.width
				height: (cardExit || (entering && !entered)) ? 0 : card.implicitHeight
				opacity: (cardExit || (entering && !entered)) ? 0.0 : 1.0
				clip: true

				transform: Translate {
					x: (wrap.cardExit || (wrap.entering && !wrap.entered)) ? 60 : 0
					Behavior on x {
						NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
					}
				}
				Behavior on height {
					NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
				}
				Behavior on opacity {
					NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
				}

				Component.onCompleted: {
					if (entering)
						enterKick.start();
					else
						entered = true;
				}

				Timer {
					id: enterKick
					interval: 16
					onTriggered: wrap.entered = true
				}

				NotificationCard {
					id: card
					anchors.left: parent.left
					anchors.right: parent.right
					anchors.top: parent.top
					notif: snap
					isToast: true
					showTime: false
					onActivated: Notifications.activate(notif.id)
					onDismissed: Notifications.dismissEntry(notif.id)
					onReplyFocusGained: replyFocus.bump(1)
					onReplyFocusLost: replyFocus.bump(-1)
				}
			}
		}
	}
}
