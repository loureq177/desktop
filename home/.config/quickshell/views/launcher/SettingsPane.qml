import "../.."
import "../../Search.js" as Search
import QtQuick

// The settings (Settings) by section, typing searches them all: Enter edits, ←/→ steps,
// blue was set here, Ctrl+R gives it back to the config, Esc steps out.
LauncherPane {
	id: pane

	// "browse" the settings, "choose" from the choices of `editing`, or
	// "type" a value for it.
	property string mode: "browse"
	property var editing: null
	// The section browsed: "" lists the sections, "changed" what settings.lua holds.
	property string section: ""
	property int sectionIndex: 0
	// Where browsing was, to come back to.
	property string browseQuery: ""
	property int browseIndex: 0

	readonly property string q: query.trim()
	readonly property var current: mode === "browse" ? (list.items[list.currentIndex]?.setting ?? null) : editing
	readonly property var changedEntries: Settings.entries.filter(e => Settings.changed(e))
	readonly property string sectionLabel: section === "changed" ? "Changed here" : Settings.humanize(section)

	icon: mode === "browse" ? "settings" : "pencil"
	grid: mode === "browse"
	placeholder: mode === "choose" ? "Pick " + editing.label.toLowerCase() + "..."
		: mode === "type" ? "A value for " + editing.label.toLowerCase() + range(editing)
		: !Settings.loaded ? "Loading settings..."
		: section !== "" ? "Search " + sectionLabel.toLowerCase() + "..."
		: "Search " + Settings.entries.length + " settings..."
	preferredHeight: list.preferredHeight
	footer: {
		if (Settings.lastError !== "")
			return "⚠ " + Settings.lastError;
		var e = current;
		if (!e)
			return mode === "browse" && section === "" && list.count > 0 ? "Enter opens the section · type to search every setting" : "";
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
		if (mode !== "browse")
			leave();
		else if (section !== "")
			openSection("");
		else
			return false;
		return true;
	}

	// Into a section (its own list, its own search), or back out to the sections.
	function openSection(key: string): void {
		var index = key === "" ? sectionIndex : 0;
		if (key !== "")
			sectionIndex = list.currentIndex;
		section = key;
		pane.queryRequested("");
		Qt.callLater(() => list.currentIndex = index);
	}

	function resetValue(): void {
		if (current)
			keepIndex(() => Settings.reset(current));
	}

	function opened(): void {
		mode = "browse";
		editing = null;
		section = "";
		Settings.lastError = "";
		Settings.refresh();
	}

	function closed(): void {
		mode = "browse";
		editing = null;
		section = "";
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

	// What settings.lua holds first, then the look and Hyprland's sections.
	function sectionRows(): var {
		var changed = changedEntries.length;
		var rows = Settings.sections.map(s => {
			var n = changedEntries.filter(e => e.section === s.key).length;
			return {
				label: s.label,
				subtitle: (s.key === "look" ? "ui.toml · " : "Hyprland · ") + s.count + " settings" + (n > 0 ? " · " + n + " changed" : ""),
				lineIcon: s.icon,
				run: () => {
					pane.openSection(s.key);
					return false;
				}
			};
		});
		if (changed > 0)
			rows.unshift({
				label: "Changed here",
				subtitle: changed + " in settings.lua, Ctrl+R gives one back",
				lineIcon: "pencil",
				run: () => {
					pane.openSection("changed");
					return false;
				}
			});
		return rows;
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
			if (pane.mode === "browse" && pane.section === "" && pane.q === "")
				return pane.sectionRows();
			var all = pane.section === "" ? Settings.entries
				: pane.section === "changed" ? pane.changedEntries
				: Settings.entries.filter(e => e.section === pane.section);
			var shown = pane.mode === "type" ? [pane.editing] : Search.rank(all, e => pane.score(e));
			return shown.map(e => ({
				label: e.label,
				subtitle: pane.section === "" && pane.mode === "browse" ? e.group : e.desc,
				heading: pane.q !== "" || pane.mode !== "browse" ? "" : pane.section === "changed" ? e.group : e.sub,
				lineIcon: e.icon,
				setting: e,
				run: () => {
					pane.enter(e);
					return false;
				}
			}));
		}

		emptyText: !Settings.loaded ? "Loading settings..." : pane.section === "changed" && pane.q === "" ? "Nothing changed here" : "No setting by that name"
	}
}
