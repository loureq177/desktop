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
	property int maxToasts: 4

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
			actions: (n.actions || []).map(a => ({ identifier: a.identifier || "", text: a.text || "" })),
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
			out.push({ identifier: all[i].identifier || "", text: label, snapId: id, toastId: id });
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
	function historyTimeById(id: int): var {
		for (var i = 0; i < root.history.length; i++) {
			if (root.history[i] && root.history[i].id === id)
				return root.history[i].time;
		}
		return null;
	}

	// Snapshot lookup by id (stable source once the sender is gone).
	function historyById(id: int): var {
		for (var i = 0; i < root.history.length; i++) {
			if (root.history[i] && root.history[i].id === id)
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
		var targetId = id !== undefined && id !== null && id >= 0 ? id : root.latestToastId();
		var found = root.liveById(targetId);
		var acts = root.visibleActions(found);
		if (index < 0 || index >= acts.length)
			return;
		if (root.handleLocalAction(targetId, acts[index].identifier))
			return;
		acts[index].invoke();
		if (!found.resident)
			root.safeDismiss(found);
	}

	function invokeByIdentifier(id: int, identifier: string): void {
		if (root.handleLocalAction(id, identifier))
			return;
		var found = root.liveById(id);
		if (found && found.actions) {
			for (var j = 0; j < found.actions.length; j++) {
				if (found.actions[j].identifier === identifier) {
					found.actions[j].invoke();
					if (!found.resident)
						root.safeDismiss(found);
					return;
				}
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

	// Expiry sweeper: non-critical toasts drop off the visual stack after
	// toastTimeoutMs so a forgotten stack cannot block its corner forever.
	// The underlying notification is intentionally NOT closed here: it stays
	// tracked until it leaves the history (pruneHistory) or the user dismisses
	// it, which keeps action buttons / inline reply working from the center.
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
					root.removeToast(t.id);
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
			n.tracked = true;
			var now = Date.now();
			root.history = [root.snapshot(n, now)].concat(root.history).slice(0, root.historyLimit);
			root.pruneHistory();
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
