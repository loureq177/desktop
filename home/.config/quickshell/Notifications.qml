pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

// Two lists of rows, newest first: `history` for the center and `toasts` for
// the popups. A row copies the notification's fields (see row()), so the
// center keeps showing it after its app has closed it.
Singleton {
	id: root

	property bool dnd: false
	readonly property ListModel history: ListModel {}
	readonly property ListModel toasts: ListModel {}
	readonly property int historyLimit: 100
	readonly property int maxToasts: 4
	readonly property int toastTimeoutMs: 5000

	// Milliseconds since the epoch: far past what an int holds.
	property double lastSoundAt: 0
	property var pendingUpdates: ({})

	function row(n): var {
		var now = Date.now();
		return {
			nid: n.id,
			appName: n.appName || n.desktopEntry || "",
			desktopEntry: n.desktopEntry || "",
			summary: n.summary || "",
			body: n.body || "",
			urgency: n.urgency,
			image: n.image || "",
			appIcon: n.appIcon || "",
			actions: root.buttonActions(n.actions),
			time: now,
			// For a toast: when its timeout started (see the expiry timer).
			shownAt: now,
			timeout: root.toastTimeoutFor(n)
		};
	}

	// The actions worth a button: "default" is a click on the card itself.
	function buttonActions(actions): var {
		var out = [];
		for (var i = 0; i < actions.length; i++) {
			var ident = (actions[i].identifier || "").trim();
			var label = (actions[i].text || "").trim();
			if (ident === "" || ident === "default" || ident === "settings")
				continue;
			if (label === "" || label.toLowerCase() === "action" || label.toLowerCase() === "activate")
				continue;
			out.push({ identifier: actions[i].identifier, text: label });
		}
		return out;
	}

	function toastTimeoutFor(n): int {
		if (n.urgency === NotificationUrgency.Critical || n.expireTimeout === 0)
			return 0;
		if (n.expireTimeout > 0)
			return n.expireTimeout < 100 ? Math.round(n.expireTimeout * 1000) : n.expireTimeout;
		return root.toastTimeoutMs;
	}

	function indexIn(model, nid): int {
		for (var i = 0; i < model.count; i++) {
			if (model.get(i).nid === nid)
				return i;
		}
		return -1;
	}

	function removeFrom(model, nid): void {
		var i = root.indexIn(model, nid);
		if (i >= 0)
			model.remove(i);
	}

	// The notification itself, while its app still has it open.
	function live(nid): var {
		return server.trackedNotifications.values.find(n => n.id === nid) ?? null;
	}

	function playSound(): void {
		var now = Date.now();
		if (now - root.lastSoundAt < 250)
			return;
		root.lastSoundAt = now;
		Quickshell.execDetached(["paplay", "/usr/share/sounds/freedesktop/stereo/message.oga"]);
	}

	function showToast(n): void {
		if (root.dnd && n.urgency !== NotificationUrgency.Critical)
			return;
		var i = root.indexIn(root.toasts, n.id);
		if (i >= 0) {
			root.toasts.set(i, root.row(n));
			root.toasts.move(i, 0, 1);
		} else {
			root.toasts.insert(0, root.row(n));
			if (root.toasts.count > root.maxToasts)
				root.toasts.remove(root.maxToasts, root.toasts.count - root.maxToasts);
		}
		root.playSound();
	}

	// A replaced notification (replaces_id) keeps its object and changes its
	// properties, several at once: collect them into one update.
	function queueUpdate(nid): void {
		root.pendingUpdates[nid] = true;
		Qt.callLater(root.flushUpdates);
	}

	function flushUpdates(): void {
		var pending = root.pendingUpdates;
		root.pendingUpdates = {};
		for (var key in pending) {
			var n = root.live(Number(key));
			if (!n)
				continue;
			var i = root.indexIn(root.history, n.id);
			if (i >= 0)
				root.history.set(i, root.row(n));
			else
				root.history.insert(0, root.row(n));
			root.showToast(n);
		}
	}

	function dismiss(nid): void {
		root.live(nid)?.dismiss();
		root.removeFrom(root.toasts, nid);
		root.removeFrom(root.history, nid);
	}

	function invoke(nid, identifier: string): void {
		var n = root.live(nid);
		var action = n?.actions.find(a => a.identifier === identifier);
		if (!action)
			return;
		action.invoke();
		if (n.resident)
			root.removeFrom(root.toasts, nid);
		else
			root.dismiss(nid);
	}

	// A click on the card: its default action, or else its app's window.
	function activate(nid): void {
		var action = root.live(nid)?.actions.find(a => a.identifier === "default");
		if (action) {
			action.invoke();
		} else {
			var i = root.indexIn(root.history, nid);
			var entry = i >= 0 ? root.history.get(i) : null;
			if (entry && (entry.desktopEntry || entry.appName))
				Hypr.focusApp(entry.desktopEntry || entry.appName);
		}
		root.removeFrom(root.toasts, nid);
	}

	function clear(): void {
		for (var n of server.trackedNotifications.values.slice())
			n.dismiss();
		root.toasts.clear();
		root.history.clear();
	}

	function dismissLatest(): void {
		var latest = root.toasts.count > 0 ? root.toasts : root.history;
		if (latest.count > 0)
			root.dismiss(latest.get(0).nid);
	}

	Timer {
		interval: 500
		running: root.toasts.count > 0
		repeat: true
		onTriggered: {
			var now = Date.now();
			for (var i = root.toasts.count - 1; i >= 0; i--) {
				var t = root.toasts.get(i);
				if (t.timeout === 0)
					continue;
				// Only the toast goes: the notification stays open in the
				// center, where its actions still have to work.
				if (now - t.shownAt >= t.timeout)
					root.toasts.remove(i);
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

		onNotification: n => {
			var appName = (n.appName || n.desktopEntry || "").trim();
			if (n.summary.trim() === "" && n.body.trim() === "" && appName === "" && !n.image)
				return;
			n.tracked = true;
			var id = n.id;
			root.removeFrom(root.history, id);
			root.history.insert(0, root.row(n));
			while (root.history.count > root.historyLimit) {
				root.live(root.history.get(root.historyLimit).nid)?.dismiss();
				root.history.remove(root.historyLimit);
			}
			// Kept over a reload: already seen, so no toast this time.
			if (!n.lastGeneration)
				root.showToast(n);
			var changed = () => root.queueUpdate(id);
			n.summaryChanged.connect(changed);
			n.bodyChanged.connect(changed);
			n.appNameChanged.connect(changed);
			n.appIconChanged.connect(changed);
			n.imageChanged.connect(changed);
			n.urgencyChanged.connect(changed);
			n.actionsChanged.connect(changed);
			n.closed.connect(() => root.removeFrom(root.toasts, id));
		}
	}

	IpcHandler {
		target: "notifications"

		// Returns whether this turned it on, so a caller knows to turn it off.
		function dndOn(): bool {
			var was = root.dnd;
			root.dnd = true;
			return !was;
		}
		function dndOff(): void {
			root.dnd = false;
		}
		function dismissLatest(): void {
			root.dismissLatest();
		}
	}
}
