// Notification service: owns org.freedesktop.Notifications via NotificationServer.
// Toasts survive focus changes and new windows. Opening any panel (center,
// quick settings, weather, launcher, clipboard, keybindings) drops the
// visual toast stack for good; history and live senders are kept regardless.
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
	property int maxToasts: 4

	// Non-critical toasts clear themselves after this long (critical ones
	// stay until dismissed). Focus changes and new windows never dismiss
	// toasts; the timeout exists so a forgotten stack stops covering the
	// top-right corner on its own. Everything stays in history regardless.
	property int toastTimeoutMs: 5000
	// Arrival timestamp per toast id, for the expiry sweeper below.
	property var toastArrivedAt: ({})


	// Each call spawns paplay, so collapse bursts: a flood of notifications
	// would otherwise fork one process per notification.
	property int lastSoundAt: 0

	// Opening the center hides visible toasts for good (they must not pop
	// back when the center closes). Other panels cover themselves
	// (QuickSettings, Weather, shell views).
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

	function dismissById(id: var): void {
		root.safeDismiss(root.liveById(id));
		root.removeToast(id);
	}

	// Center entries: dismiss the live notification (if any) and drop the
	// history snapshot, so the ✕ works on dead entries too.
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

	// Actions shown as buttons: mirrors entriesFromActions so the keybind
	// actions operate on exactly the rendered buttons.
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

	// Buttons for one action row: extra actions only, each with a real
	// label. The "default" action NEVER becomes a button — a click on the
	// notification body already invokes it (activate()), so a button would
	// just duplicate it. Chromium's "settings" action (opens browser
	// notification settings on web apps like WhatsApp Web) is dropped as
	// noise. Actions without a real label (empty, "Action", "Activate")
	// are skipped instead of rendered with a placeholder.
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

	// Action entries for a history/snapshot card, snapshot.actions as the
	// stable source (plain data). Buttons render even when the live
	// notification is gone; invokeByIdentifier safely no-ops then and the
	// button disables itself via invitesLive.
	function historyActionEntries(snap): var {
		return root.entriesFromActions(snap.id, snap.actions);
	}

	// Whether the live notification backing a snapshot still exists.
	// History cards use it to disable dead notification actions.
	function isLive(id: int): bool {
		return root.liveById(id) !== null;
	}

	// Arrival timestamp of a notification by id, from the history snapshot.
	// Toasts use it so the toast and the center card show the same time
	// (the toast would otherwise show its render time).
	function historyTimeById(id: var): var {
		var idStr = String(id);
		for (var i = 0; i < root.history.length; i++) {
			if (root.history[i] && String(root.history[i].id) === idStr)
				return root.history[i].time;
		}
		return null;
	}

	// Snapshot lookup by id (stable source once the sender is gone).
	function historyById(id: var): var {
		var idStr = String(id);
		for (var i = 0; i < root.history.length; i++) {
			if (root.history[i] && String(root.history[i].id) === idStr)
				return root.history[i];
		}
		return null;
	}

	// check-updates sends fire-and-forget (it must not block the systemd
	// service on a listener), so the "update" action has no live sender to
	// answer it. Handle it locally instead: open the updater in a terminal.
	// The Hyprland rule floats it by window title (ghostty ignores --class).
	function launchSysupdate(): void {
		Quickshell.execDetached(["ghostty", "-e", Quickshell.env("HOME") + "/.local/bin/sysupdate"]);
	}

	// Locally-handled actions: currently only the "System Update" update
	// button. Works from the live object or the history snapshot, so clicks
	// keep working long after the sender exited.
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

	// Shared action invocation for toasts, center buttons and keybinds.
	// Index-based for keybinds (SUPER+ALT+1..3 act on the latest toast,
	// indexing the visible actions); identifier-based for buttons.
	function invokeAction(index: int, id: var): void {
		// Explicit -1 (e.g. stale rowId) must be a no-op, never a fallback
		// to the latest toast — otherwise X/Enter on a swept row hits a
		// random newest notification.
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

	// Body click / Enter: run the app's default action (open the chat, etc.),
	// focus the app window if possible, remove toast and close the center drawer
	// instead of wiping the entry from history.
	function activate(id: var): void {
		// Same no-op rule as invokeAction: stale -1 never falls back.
		if (id === -1)
			return;
		var targetId = id !== undefined && id !== null && id >= 0 ? id : root.latestToastId();
		if (targetId < 0)
			return;
		var snap = root.historyById(targetId);
		var found = root.liveById(targetId);
		var invoked = false;

		if (root.handleLocalAction(targetId, "default") || root.handleLocalAction(targetId, "update")) {
			invoked = true;
		} else if (found && found.actions) {
			for (var i = 0; i < found.actions.length; i++) {
				if (found.actions[i] && found.actions[i].identifier === "default") {
					found.actions[i].invoke();
					invoked = true;
					break;
				}
			}
			// NOTE: intentionally no fallback to actions[0]. A body click
			// must run the default action only — firing an arbitrary first
			// action (e.g. "Delete" instead of "Open") is destructive.
		}

		var appTarget = (found && (found.desktopEntry || found.appName)) || (snap && (snap.desktopEntry || snap.appName)) || "";
		if (appTarget !== "") {
			Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", appTarget]);
		}

		root.removeToast(targetId);
		root.closeCenter();
	}


	// ─── Operations (used by IPC, the center UI and scripts alike) ─────────────

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

	// Drop the visual toast stack without touching history or live
	// senders: opening a panel slides the toast out and it never comes
	// back, while center action buttons stay live.
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
		// safeDismiss, not dismiss(): dismissing an already-destroyed
		// notification logs "Cannot close destroyed notification".
		var vals = server.trackedNotifications.values.slice();
		for (var i = 0; i < vals.length; i++)
			root.safeDismiss(vals[i]);
		root.toasts = [];
		root.history = [];
	}

	// Removal from history is enough: the center's visual model keeps the
	// row until its collapse animation finishes (same for ✕, X, SUPER+,).
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
			return 0; // 0 = never auto-expire
		// DBus delivers expireTimeout in milliseconds (e.g. notify-send -t 5000 passes 5000).
		// If a sender mistakenly passes seconds (e.g. < 100), convert to ms.
		if (t.expireTimeout > 0)
			return t.expireTimeout < 100 ? Math.round(t.expireTimeout * 1000) : t.expireTimeout;
		return root.toastTimeoutMs;
	}

	// Expiry sweeper: non-critical toasts drop off the visual stack after
	// the requested timeout (expireTimeout) or toastTimeoutMs so a forgotten stack
	// cannot block its corner forever. Expired notifications are also dismissed
	// so waiting senders (e.g. notify-send -A) unblock cleanly.
	// Ticks only while toasts exist.
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

	// Close live notifications that fell out of the history cap so tracked
	// state cannot grow without bound (toast expiry keeps them alive on
	// purpose — see the sweeper note above).
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
				// Silent while DND is on; critical notifications still announce.
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
