// Notification service: owns org.freedesktop.Notifications via NotificationServer.
// Toasts survive focus changes, new windows, and opening/closing the center.
// Non-critical toasts expire after toastTimeoutMs; critical ones stay until
// dismissed. Everything is kept in history regardless.
// Critical notifications always pop and never expire. Non-critical popups are
// suppressed while DND is on but are still kept in history.
// Control via IPC: `qs ipc call notifications <toggle|toggleDnd|dndOn|dndOff|
// clear|dismissLatest|invokeAction|invokeDefault|status>`.
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

Singleton {
	id: root

	property bool dnd: false
	property bool centerOpen: false
	// Live toast objects (sticky, newest first). Reassigned on every change
	// so bindings update (in-place mutation does not notify).
	property var toasts: []
	// Plain snapshots for the control center (live objects die on dismiss).
	property var history: []
	property int historyLimit: 100

	// Non-critical toasts clear themselves after this long (critical ones
	// stay until dismissed). Focus changes and new windows never dismiss
	// toasts; the timeout exists so a forgotten stack stops covering the
	// top-right corner on its own. Everything stays in history regardless.
	property int toastTimeoutMs: 12000
	// Arrival timestamp per toast id, for the expiry sweeper below.
	property var toastArrivedAt: ({})


	// Each call spawns paplay, so collapse bursts: a flood of notifications
	// would otherwise fork one process per notification.
	property int lastSoundAt: 0

	function playSound(): void {
		var now = Date.now();
		if (now - root.lastSoundAt < 250)
			return;
		root.lastSoundAt = now;
		Quickshell.execDetached(["paplay", "/usr/share/sounds/freedesktop/stereo/message.oga"]);
	}

	function snapshot(n, when): var {
		return {
			id: n.id,
			appName: n.appName || n.desktopEntry || "",
			summary: n.summary || "",
			body: n.body || "",
			urgency: n.urgency,
			image: n.image || "",
			appIcon: n.appIcon || "",
			actions: (n.actions || []).map(a => ({ identifier: a.identifier || "", text: a.text || "Action" })),
			time: when
		};
	}

	function removeToast(id: int): void {
		delete root.toastArrivedAt[id];
		var kept = [];
		for (var i = 0; i < root.toasts.length; i++) {
			if (root.toasts[i] && root.toasts[i].id !== id)
				kept.push(root.toasts[i]);
		}
		root.toasts = kept;
	}

	function latestToast(): var {
		return root.toasts.length > 0 ? root.toasts[0] : null;
	}

	function latestToastId(): int {
		return root.toasts.length > 0 && root.toasts[0] ? root.toasts[0].id : -1;
	}

	function liveById(id: int): var {
		var vals = server.trackedNotifications.values;
		for (var i = 0; i < vals.length; i++) {
			if (vals[i] && vals[i].id === id)
				return vals[i];
		}
		return null;
	}

	// dismiss() on an already-destroyed Notification logs
	// "Cannot close destroyed notification", so verify membership first.
	function safeDismiss(n): void {
		if (!n)
			return;
		var vals = server.trackedNotifications.values;
		for (var i = 0; i < vals.length; i++) {
			if (vals[i] === n) {
				n.dismiss();
				return;
			}
		}
	}

	function dismissById(id: int): void {
		root.safeDismiss(root.liveById(id));
	}

	// Center entries: dismiss the live notification (if any) and drop the
	// history snapshot, so the ✕ works on dead entries too.
	function removeHistory(id: int): void {
		var kept = [];
		for (var i = 0; i < root.history.length; i++) {
			if (root.history[i] && root.history[i].id !== id)
				kept.push(root.history[i]);
		}
		root.history = kept;
	}

	function dismissEntry(id: int): void {
		root.safeDismiss(root.liveById(id));
		root.removeHistory(id);
	}

	// Actions shown as buttons: everything except the "default" action,
	// which a body click invokes directly (open/reply semantics).
	function visibleActions(n): var {
		var out = [];
		if (!n || !n.actions)
			return out;
		for (var i = 0; i < n.actions.length; i++) {
			if (n.actions[i].identifier !== "default")
				out.push(n.actions[i]);
		}
		return out;
	}

	// Shared action invocation for toasts, center buttons and keybinds.
	// Index-based for keybinds (SUPER+ALT+1..3 act on the latest toast,
	// indexing the visible actions); identifier-based for buttons.
	function invokeAction(index: int, id: var): void {
		var targetId = id !== undefined && id !== null && id >= 0 ? id : root.latestToastId();
		var found = root.liveById(targetId);
		var acts = root.visibleActions(found);
		if (index < 0 || index >= acts.length)
			return;
		acts[index].invoke();
		if (!found.resident)
			root.safeDismiss(found);
	}

	function invokeByIdentifier(id: int, identifier: string): void {
		var found = root.liveById(id);
		if (!found || !found.actions)
			return;
		for (var j = 0; j < found.actions.length; j++) {
			if (found.actions[j].identifier === identifier) {
				found.actions[j].invoke();
				if (!found.resident)
					root.safeDismiss(found);
				return;
			}
		}
	}

	// Body click: run the app's default action (open the chat, etc.),
	// falling back to plain dismissal when there is none.
	function activate(id: var): void {
		var targetId = id !== undefined && id !== null && id >= 0 ? id : root.latestToastId();
		var found = root.liveById(targetId);
		var acts = found ? found.actions : [];
		for (var i = 0; i < acts.length; i++) {
			if (acts[i].identifier === "default") {
				acts[i].invoke();
				if (!found.resident)
					root.safeDismiss(found);
				return;
			}
		}
		root.dismissById(targetId);
	}

	// ─── Operations (used by IPC, the center UI and scripts alike) ─────────────

	function toggle(): void {
		if (root.centerOpen)
			root.closeCenter();
		else
			root.centerOpen = true;
	}

	function closeCenter(): void {
		root.centerOpen = false;
	}

	function dismissToasts(): void {
		var vals = root.toasts.slice();
		for (var i = 0; i < vals.length; i++)
			root.safeDismiss(vals[i]);
	}

	function toggleDnd(): void {
		root.dnd = !root.dnd;
	}

	function dndOn(): void {
		root.dnd = true;
	}

	function dndOff(): void {
		root.dnd = false;
	}

	function clear(): void {
		// safeDismiss, not dismiss(): dismissing an already-destroyed
		// notification logs "Cannot close destroyed notification".
		var vals = server.trackedNotifications.values.slice();
		for (var i = 0; i < vals.length; i++)
			root.safeDismiss(vals[i]);
		root.toasts = [];
		root.history = [];
	}

	function dismissLatest(): void {
		root.safeDismiss(root.latestToast());
	}

	function status(): string {
		return JSON.stringify({ count: root.toasts.length, dnd: root.dnd, total: root.history.length });
	}

	// Expiry sweeper: non-critical toasts dismiss themselves after
	// toastTimeoutMs so a forgotten stack cannot block its corner forever.
	// Ticks only while toasts exist.
	Timer {
		interval: 1000
		running: root.toasts.length > 0
		repeat: true
		onTriggered: {
			var now = Date.now();
			var liveIds = {};
			var vals = root.toasts.slice();
			for (var i = 0; i < vals.length; i++) {
				var t = vals[i];
				if (!t)
					continue;
				liveIds[t.id] = true;
				if (t.urgency === NotificationUrgency.Critical)
					continue;
				var at = root.toastArrivedAt[t.id];
				if (at === undefined) {
					root.toastArrivedAt[t.id] = now;
					continue;
				}
				if (now - at >= root.toastTimeoutMs)
					root.safeDismiss(t);
			}
			for (var key in root.toastArrivedAt) {
				if (!liveIds[key])
					delete root.toastArrivedAt[key];
			}
		}
	}

	NotificationServer {
		id: server
		keepOnReload: true
		bodySupported: true
		bodyMarkupSupported: false
		actionsSupported: true
		imageSupported: true
		persistenceSupported: false
		inlineReplySupported: false

		onNotification: n => {
			n.tracked = true;
			var now = Date.now();
			root.history = [root.snapshot(n, now)].concat(root.history).slice(0, root.historyLimit);
			root.toastArrivedAt[n.id] = now;
			var critical = (n.urgency === NotificationUrgency.Critical);
			if (!root.dnd || critical)
				root.toasts = [n].concat(root.toasts);
			n.closed.connect(() => {
				root.removeToast(n.id);
			});
			// Silent while DND is on; critical notifications still announce.
			if (!root.dnd || critical)
				root.playSound();
		}
	}

	IpcHandler {
		target: "notifications"

		function toggle(): void {
			root.toggle();
		}
		function toggleDnd(): void {
			root.toggleDnd();
		}
		function dndOn(): void {
			root.dndOn();
		}
		function dndOff(): void {
			root.dndOff();
		}
		function clear(): void {
			root.clear();
		}
		function dismissLatest(): void {
			root.dismissLatest();
		}
		function invokeAction(index: int): void {
			root.invokeAction(index);
		}
		function invokeDefault(): void {
			root.activate();
		}
		function status(): string {
			return root.status();
		}
	}
}
