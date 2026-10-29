import "../.."
import "../../Search.js" as Search
import QtQuick

// Every setting (Settings) with its value: Enter edits, ←/→ steps, blue was set here,
// Ctrl+R gives it back to the config, Esc steps out.
LauncherPane {
	id: pane

	// "browse" the settings, "choose" from the choices of `editing`, or
	// "type" a value for it.
	property string mode: "browse"
	property var editing: null
	// Where browsing was, to come back to.
	property string browseQuery: ""
	property int browseIndex: 0

	readonly property string q: query.trim()
	readonly property var current: mode === "browse" ? (list.items[list.currentIndex]?.setting ?? null) : editing

	icon: mode === "browse" ? "settings" : "pencil"
	grid: mode === "browse"
	placeholder: mode === "choose" ? "Pick " + editing.label.toLowerCase() + "..."
		: mode === "type" ? "A value for " + editing.label.toLowerCase() + range(editing)
		: Settings.loaded ? "Search " + Settings.entries.length + " settings..." : "Loading settings..."
	preferredHeight: list.preferredHeight
	footer: {
		if (Settings.lastError !== "")
			return "⚠ " + Settings.lastError;
		var e = current;
		if (!e)
			return "";
		if (mode === "type")
			return "Enter sets it · Esc leaves it" + (e.source === "ui" ? " · the shell restarts with the new look" : "");
		if (mode === "choose")
			return "Enter picks it · Esc leaves it";
		var keys = e.kind === "bool" ? "Enter or ←/→ switches" : e.kind === "enum" ? "←/→ or Enter picks" : "Enter types a value" + (e.kind === "int" || e.kind === "float" ? " · ←/→ steps" : "");
		if (e.source === "ui")
			keys = (e.kind === "bool" ? "Enter switches" : e.kind === "enum" ? "Enter picks" : "Enter types a value") + " · the shell restarts with it";
		if (e.source === "hyprland")
			return e.name + range(e) + " · Hyprland's default " + Settings.display(Object.assign({}, e, { value: e.defaultValue })) + " · " + keys + (Settings.changed(e) ? " · Ctrl+R: the config's" : "");
		return e.name + " · " + keys;
	}

	// Every word typed matches somewhere ("blur passes"), the best fields
	// first: the name, the option's own, its section, what it does.
	function score(e: var): int {
		var total = 0;
		for (const word of q.split(/\s+/)) {
			var s = Search.matchScore([[e.label, 0], [e.name, 3], [e.group, 5], [e.desc, 8], [e.keywords ?? "", 8]], word);
			if (s === -1)
				return -1;
			total += s;
		}
		return total;
	}

	function range(e: var): string {
		return e && e.min !== null && e.min !== undefined && e.max !== null && e.max !== undefined ? " (" + e.min + "–" + e.max + ")" : "";
	}

	function step(delta: int, repeat: bool): void {
		list.step(delta, repeat);
	}

	function stepColumn(delta: int, repeat: bool): void {
		var e = current;
		if (!e || e.source === "ui")
			return;
		keepIndex(() => Settings.set(e, Settings.stepped(e, delta)));
	}

	function activate(): void {
		list.activate();
	}

	function back(): bool {
		if (mode === "browse")
			return false;
		leave();
		return true;
	}

	function resetValue(): void {
		if (current)
			keepIndex(() => Settings.reset(current));
	}

	function opened(): void {
		mode = "browse";
		editing = null;
		Settings.lastError = "";
		Settings.refresh();
	}

	function closed(): void {
		mode = "browse";
		editing = null;
	}

	// The list is made again as a value changes: the row stays selected.
	function keepIndex(change: var): void {
		var index = list.currentIndex;
		change();
		Qt.callLater(() => list.currentIndex = Math.min(index, list.count - 1));
	}

	function enter(e: var): void {
		if (mode === "type") {
			var value = Settings.parse(editing, query);
			if (value === undefined) {
				Settings.lastError = "Not a value " + editing.label.toLowerCase() + " can take" + range(editing);
				return;
			}
			Settings.set(editing, value);
			leave();
			return;
		}
		if (e.kind === "bool") {
			keepIndex(() => Settings.set(e, !e.value));
			return;
		}
		browseQuery = query;
		browseIndex = list.currentIndex;
		editing = e;
		mode = e.kind === "enum" ? "choose" : "type";
		Settings.lastError = "";
		pane.queryRequested(mode === "type" ? (e.kind === "color" && e.source === "hyprland" ? Settings.hyprColorInput(String(e.value)) : String(e.value)) : "");
	}

	function pick(value: var): void {
		Settings.set(editing, value);
		leave();
	}

	function leave(): void {
		mode = "browse";
		editing = null;
		pane.queryRequested(browseQuery);
		var index = browseIndex;
		Qt.callLater(() => list.currentIndex = index);
	}

	onQueryChanged: {
		if (mode !== "type")
			list.reset();
	}

	ResultList {
		id: list
		anchors.fill: parent

		items: {
			if (pane.mode === "choose")
				return Search.rank(pane.editing.choices, c => Search.matchScore([[String(c.label), 0]], pane.q)).map(c => ({
					label: String(c.label),
					subtitle: c.value === pane.editing.value ? "now" : "",
					lineIcon: c.value === pane.editing.value ? "check" : "",
					run: () => {
						pane.pick(c.value);
						return false;
					}
				}));
			var shown = pane.mode === "type" ? [pane.editing]
				: Search.rank(Settings.entries, e => pane.score(e));
			return shown.map(e => ({
				label: e.label,
				subtitle: pane.q === "" || pane.mode === "type" ? e.desc : e.group,
				heading: pane.q === "" && pane.mode === "browse" ? e.group : "",
				lineIcon: e.icon,
				setting: e,
				run: () => {
					pane.enter(e);
					return false;
				}
			}));
		}

		emptyText: Settings.loaded ? "No setting by that name" : "Loading settings..."
	}
}
