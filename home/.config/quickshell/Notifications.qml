pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

Singleton {
	id: root

	property bool dnd: false
	property bool centerOpen: false
	property var toasts: []
	property var history: []
	property int historyLimit: 100
	property int maxToasts: 4

	property int toastTimeoutMs: 5000
	property var toastArrivedAt: ({})

	property int lastSoundAt: 0

	onCenterOpenChanged: {
		if (root.centerOpen)
			root.hideToasts();
	}

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
			desktopEntry: n.desktopEntry || "",
			summary: n.summary || "",
			body: n.body || "",
			urgency: n.urgency,
			image: n.image || "",
			appIcon: n.appIcon || "",
			actions: (n.actions || []).map(a => ({ identifier: a.identifier || "", text: a.text || "" })),
			time: when
		};
	}

	function removeToast(id: var): void {
		delete root.toastArrivedAt[id];
		var idStr = String(id);
		var kept = [];
		for (var i = 0; i < root.toasts.length; i++) {
			var t = root.toasts[i];
			if (t && String(t.id) !== idStr)
				kept.push(t);
		}
		root.toasts = kept;
	}

	function latestToast(): var {
		return root.toasts.length > 0 ? root.toasts[0] : null;
	}

	function latestToastId(): int {
		return root.toasts.length > 0 && root.toasts[0] ? root.toasts[0].id : -1;
	}

	function liveById(id: var): var {
		var idStr = String(id);
		var vals = server.trackedNotifications.values;
		for (var i = 0; i < vals.length; i++) {
			if (vals[i] && String(vals[i].id) === idStr)
				return vals[i];
		}
		return null;
	}

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

	function dismissById(id: var): void {
		root.safeDismiss(root.liveById(id));
		root.removeToast(id);
	}

	function removeHistory(id: var): void {
		var idStr = String(id);
		var kept = [];
		for (var i = 0; i < root.history.length; i++) {
			var h = root.history[i];
			if (h && String(h.id) !== idStr)
				kept.push(h);
		}
		root.history = kept;
	}

	function dismissEntry(id: var): void {
		root.safeDismiss(root.liveById(id));
		root.removeToast(id);
		root.removeHistory(id);
	}

	function visibleActions(n): var {
		var entries = root.entriesFromActions(n ? n.id : -1, n ? n.actions : []);
		var want = {};
		for (var i = 0; i < entries.length; i++)
			want[entries[i].identifier] = true;
		var out = [];
		if (!n || !n.actions)
			return out;
		for (var j = 0; j < n.actions.length; j++) {
			if (n.actions[j] && want[(n.actions[j].identifier || "")] === true)
				out.push(n.actions[j]);
		}
		return out;
	}

	function entriesFromActions(id, acts): var {
		var out = [];
		var all = acts || [];
		for (var i = 0; i < all.length; i++) {
			var ident = ((all[i] && all[i].identifier) || "").trim();
			if (ident === "" || ident === "default" || ident === "settings")
				continue;
			var label = ((all[i] && (all[i].text || all[i].label)) || "").trim();
			var lower = label.toLowerCase();
			if (label === "" || lower === "action" || lower === "activate")
				continue;
			out.push({ identifier: all[i].identifier || "", text: label, notifId: id });
		}
		return out;
	}

	function historyActionEntries(snap): var {
		return root.entriesFromActions(snap.id, snap.actions);
	}

	function isLive(id: int): bool {
		return root.liveById(id) !== null;
	}

	function historyTimeById(id: var): var {
		var idStr = String(id);
		for (var i = 0; i < root.history.length; i++) {
			if (root.history[i] && String(root.history[i].id) === idStr)
				return root.history[i].time;
		}
		return null;
	}

	function historyById(id: var): var {
		var idStr = String(id);
		for (var i = 0; i < root.history.length; i++) {
			if (root.history[i] && String(root.history[i].id) === idStr)
				return root.history[i];
		}
		return null;
	}

	function launchSysupdate(): void {
		Quickshell.execDetached(["ghostty", "+new-window", "-e", Quickshell.env("HOME") + "/.local/bin/sysupdate"]);
	}

	function focusApp(appTarget: string): void {
		var literal = appTarget.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
		var selector = "class:^(?i)" + literal + "$";
		var lua = selector.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
		Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "' + lua + '" })']);
	}

	function handleLocalAction(id: int, identifier: string): bool {
		if (identifier !== "update")
			return false;
		var found = root.liveById(id);
		var app = (found && (found.appName || found.desktopEntry)) || "";
		if (app === "") {
			var snap = root.historyById(id);
			app = (snap && snap.appName) || "";
		}
		if (app !== "System Update")
			return false;
		root.launchSysupdate();
		root.dismissEntry(id);
		return true;
	}

	function invokeAction(index: int, id: var): void {
		if (id === -1)
			return;
		var targetId = id !== undefined && id !== null && id >= 0 ? id : root.latestToastId();
		var found = root.liveById(targetId);
		var acts = root.visibleActions(found);
		if (index < 0 || index >= acts.length)
			return;
		if (root.handleLocalAction(targetId, acts[index].identifier))
			return;
		acts[index].invoke();
		if (!found || !found.resident)
			root.dismissEntry(targetId);
		else
			root.removeToast(targetId);
	}

	function invokeByIdentifier(id: var, identifier: string): void {
		if (root.handleLocalAction(id, identifier))
			return;
		var found = root.liveById(id);
		if (found && found.actions) {
			for (var j = 0; j < found.actions.length; j++) {
				if (found.actions[j].identifier === identifier) {
					found.actions[j].invoke();
					if (!found.resident)
						root.dismissEntry(id);
					else
						root.removeToast(id);
					return;
				}
			}
		}
	}

	function activate(id: var): void {
		if (id === -1)
			return;
		var targetId = id !== undefined && id !== null && id >= 0 ? id : root.latestToastId();
		if (targetId < 0)
			return;
		var snap = root.historyById(targetId);
		var found = root.liveById(targetId);
		var invoked = false;

		if (root.handleLocalAction(targetId, "update")) {
			invoked = true;
		} else if (found && found.actions) {
			for (var i = 0; i < found.actions.length; i++) {
				if (found.actions[i] && found.actions[i].identifier === "default") {
					found.actions[i].invoke();
					invoked = true;
					break;
				}
			}
		}

		var appTarget = (found && (found.desktopEntry || found.appName)) || (snap && (snap.desktopEntry || snap.appName)) || "";
		if (appTarget !== "")
			root.focusApp(appTarget);

		root.removeToast(targetId);
		root.closeCenter();
	}

	function toggle(): void {
		if (root.centerOpen)
			root.closeCenter();
		else {
			QuickSettings.close();
			root.centerOpen = true;
		}
	}

	function closeCenter(): void {
		root.centerOpen = false;
	}

	function dismissToasts(): void {
		var vals = root.toasts.slice();
		for (var i = 0; i < vals.length; i++)
			root.safeDismiss(vals[i]);
		root.toasts = [];
	}

	function hideToasts(): void {
		root.toastArrivedAt = {};
		if (root.toasts.length > 0)
			root.toasts = [];
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
		var vals = server.trackedNotifications.values.slice();
		for (var i = 0; i < vals.length; i++)
			root.safeDismiss(vals[i]);
		root.toasts = [];
		root.history = [];
	}

	function dismissLatest(): void {
		var targetId = -1;
		var t = root.latestToast();
		if (t) {
			targetId = t.id;
		} else if (root.history.length > 0 && root.history[0]) {
			targetId = root.history[0].id;
		}
		if (targetId >= 0) {
			root.dismissEntry(targetId);
		}
	}

	function status(): string {
		return JSON.stringify({ count: root.toasts.length, dnd: root.dnd, total: root.history.length, history: root.history, centerOpen: root.centerOpen });
	}

	function toastTimeoutFor(t): int {
		if (t.urgency === NotificationUrgency.Critical || t.expireTimeout === 0)
			return 0;
		if (t.expireTimeout > 0)
			return t.expireTimeout < 100 ? Math.round(t.expireTimeout * 1000) : t.expireTimeout;
		return root.toastTimeoutMs;
	}

	Timer {
		interval: 500
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
				var timeout = root.toastTimeoutFor(t);
				if (timeout === 0)
					continue;
				var at = root.toastArrivedAt[t.id];
				if (at === undefined) {
					root.toastArrivedAt[t.id] = now;
					continue;
				}
				if (now - at >= timeout) {
					root.safeDismiss(t);
					root.removeToast(t.id);
				}
			}
			for (var key in root.toastArrivedAt) {
				if (!liveIds[key])
					delete root.toastArrivedAt[key];
			}
		}
	}

	function pruneHistory(): void {
		if (root.history.length <= root.historyLimit)
			return;
		var dropped = root.history.slice(root.historyLimit);
		root.history = root.history.slice(0, root.historyLimit);
		for (var i = 0; i < dropped.length; i++) {
			if (dropped[i])
				root.safeDismiss(root.liveById(dropped[i].id));
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
		inlineReplySupported: true

		onNotification: n => {
			if (!n) return;
			var summary = (n.summary || "").trim();
			var body = (n.body || "").trim();
			var appName = (n.appName || n.desktopEntry || "").trim();
			if (summary === "" && body === "" && appName === "" && !n.image)
				return;

			n.tracked = true;
			var isReload = (n.lastGeneration === true);
			var now = Date.now();
			var filtered = [];
			var nIdStr = String(n.id);
			for (var i = 0; i < root.history.length; i++) {
				if (root.history[i] && String(root.history[i].id) !== nIdStr)
					filtered.push(root.history[i]);
			}
			root.history = [root.snapshot(n, now)].concat(filtered).slice(0, root.historyLimit);
			root.pruneHistory();
			if (!isReload) {
				root.toastArrivedAt[n.id] = now;
				var critical = (n.urgency === NotificationUrgency.Critical);
				if (!root.dnd || critical) {
					var updated = [n].concat(root.toasts);
					if (updated.length > root.maxToasts) {
						var dropped = updated.slice(root.maxToasts);
						for (var d = 0; d < dropped.length; d++) {
							delete root.toastArrivedAt[dropped[d].id];
						}
						updated = updated.slice(0, root.maxToasts);
					}
					root.toasts = updated;
				}
				if (!root.dnd || critical)
					root.playSound();
			}
			n.closed.connect(() => {
				root.removeToast(n.id);
			});
		}
	}

	IpcHandler {
		target: "notifications"

		function toggle(): void {
			root.toggle();
		}
		function openCenter(): void {
			root.centerOpen = true;
		}
		function closeCenter(): void {
			root.closeCenter();
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
		function dismissToasts(): void {
			root.dismissToasts();
		}
		function hideToasts(): void {
			root.hideToasts();
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
		function activate(id: int): void {
			root.activate(id);
		}
		function dismiss(id: int): void {
			root.dismissEntry(id);
		}
		function status(): string {
			return root.status();
		}
	}
}
