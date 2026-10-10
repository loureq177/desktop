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

	property bool shown: Notifications.toasts.length > 0 && !Notifications.centerOpen && !QuickSettings.panelOpen && !Weather.panelOpen
	property int slide: Theme.notifWidth + Theme.notifRightMargin

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
