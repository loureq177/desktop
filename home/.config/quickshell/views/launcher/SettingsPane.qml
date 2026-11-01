import "../.."
import "../../Search.js" as Search
import QtQuick

// Displays, Wi-Fi, Bluetooth, audio and Hyprland, typing searches them all: Enter edits,
// ←/→ steps, blue was set here, Ctrl+R gives it back to the config, Esc steps out. What a
// setting does shows on hover.
LauncherPane {
	id: pane

	// "browse" the settings, "choose" from the choices of `editing`, or
	// "type" a value for it.
	property string mode: "browse"
	property var editing: null
	// The page browsed: "" the first, "hyprland" Hyprland's sections, "changed" what settings.lua holds.
	property string section: ""
	property int sectionIndex: 0
	property int hyprlandIndex: 0
	// Where browsing was, to come back to.
	property string browseQuery: ""
	property int browseIndex: 0

	readonly property string q: query.trim()
	readonly property var current: mode === "browse" ? (list.items[list.currentIndex]?.setting ?? null) : editing
	readonly property var changedEntries: Settings.entries.filter(e => Settings.changed(e))
	readonly property string sectionLabel: section === "changed" ? "Changed here" : Settings.humanize(section)

	icon: mode === "browse" ? "settings" : "pencil"
	grid: mode === "browse"
	placeholder: mode === "choose" ? "Pick " + editing.label.toLowerCase() + "…"
		: mode === "type" ? "A value for " + editing.label.toLowerCase() + range(editing)
		: !Settings.loaded ? "Loading settings…"
		: section !== "" ? "Search " + sectionLabel.toLowerCase() + "…"
		: "Search " + Settings.entries.length + " settings…"
	preferredHeight: list.preferredHeight
	error: Settings.lastError

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

	// What it does, its name and default, and how it changes.
	function tooltip(e: var): string {
		if (e.source === "ui")
			return e.name + " in ui.toml, for the whole desktop: the shell restarts with it";
		if (e.source === "display" && Settings.changed(e))
			return e.desc + "\nSet here: Ctrl+R gives it back to the config";
		if (e.source !== "hyprland")
			return e.desc;
		var lines = [];
		if (e.desc)
			lines.push(e.desc.charAt(0).toUpperCase() + e.desc.slice(1));
		lines.push(e.name + range(e) + " · default " + Settings.display(Object.assign({}, e, { value: e.defaultValue })));
		if (Settings.changed(e))
			lines.push("Set here: Ctrl+R gives it back to the config");
		return lines.join("\n");
	}

	function range(e: var): string {
		return e && e.min !== null && e.min !== undefined && e.max !== null && e.max !== undefined ? " (" + e.min + "–" + e.max + ")" : "";
	}

	function step(delta: int, repeat: bool): void {
		list.step(delta, repeat);
	}

	function stepColumn(delta: int, repeat: bool): void {
		var e = current;
		if (!e || e.source === "ui" || e.stepless)
			return;
		list.keepIndex(() => Settings.set(e, Settings.stepped(e, delta)));
	}

	function activate(): void {
		list.activate();
	}

	function back(): bool {
		if (mode !== "browse")
			leave();
		else if (section !== "")
			openSection(["displays", "audio", "hyprland"].includes(section) ? "" : "hyprland");
		else
			return false;
		return true;
	}

	// Into a page (its own list, its own search), or back out to where it was opened from.
	function openSection(key: string): void {
		var out = key === "" || (key === "hyprland" && section !== "");
		var index = !out ? 0 : key === "" ? sectionIndex : hyprlandIndex;
		if (!out && section === "")
			sectionIndex = list.currentIndex;
		else if (!out)
			hyprlandIndex = list.currentIndex;
		section = key;
		pane.queryRequested("");
		Qt.callLater(() => list.currentIndex = index);
	}

	function resetValue(): void {
		if (current)
			list.keepIndex(() => Settings.reset(current));
	}

	function opened(): void {
		mode = "browse";
		editing = null;
		section = "";
		Settings.lastError = "";
		Settings.refresh();
		Brightness.read();
		list.rewind();
	}

	function closed(): void {
		mode = "browse";
		editing = null;
		section = "";
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
			list.keepIndex(() => Settings.set(e, !e.value));
			return;
		}
		browseQuery = query;
		browseIndex = list.currentIndex;
		editing = e;
		mode = e.kind === "enum" ? "choose" : "type";
		list.currentIndex = 0;
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

	function page(label: string, subtitle: string, icon: string, run: var): var {
		return { label: label, subtitle: subtitle, lineIcon: icon, run: run };
	}

	function openPage(key: string): var {
		return () => {
			pane.openSection(key);
			return false;
		};
	}

	// Wi-Fi and Bluetooth have their pages in Actions.
	readonly property var actionsPages: [
		page("Wi-Fi", Net.wifiStatus, Net.wifiUp ? "wifi" : "wifi-off", () => Commands.get("wifi").run()),
		page("Bluetooth", Bt.status, Bt.icon, () => Commands.get("bluetooth").run())
	]

	function pageRows(): var {
		var screens = Settings.monitors.map(m => m.width + "x" + m.height + " · " + Math.round(m.refreshRate) + " Hz").join(", ");
		return [page("Displays", screens, "monitor", openPage("displays"))].concat(actionsPages, [
			page("Audio", Audio.sink?.description ?? "", Audio.icon, openPage("audio")),
			page("Hyprland", Settings.hyprlandEntries.length + " settings, and the look", "layout-grid", openPage("hyprland"))
		]);
	}

	// What settings.lua holds first, then the look and Hyprland's sections.
	function sectionRows(): var {
		var changed = changedEntries.length;
		var rows = Settings.sections.map(s => {
			var n = changedEntries.filter(e => e.section === s.key).length;
			return {
				label: s.label,
				subtitle: (s.key === "look" ? "ui.toml · " : "Hyprland · ") + s.count + (s.count === 1 ? " setting" : " settings") + (n > 0 ? " · " + n + " changed" : ""),
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

		// Displays and audio answer later than the keypress: a new model would go back to the top.
		onRowsChanged: {
			var index = currentIndex;
			items = rows;
			currentIndex = Math.min(index, count - 1);
		}
		Component.onCompleted: items = rows

		readonly property var rows: {
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
			if (pane.mode === "browse" && pane.q === "" && pane.section === "")
				return pane.pageRows();
			if (pane.mode === "browse" && pane.q === "" && pane.section === "hyprland")
				return pane.sectionRows();
			var all = pane.section === "" ? Settings.entries
				: pane.section === "hyprland" ? Settings.hyprlandEntries
				: pane.section === "changed" ? pane.changedEntries
				: Settings.entries.filter(e => e.section === pane.section);
			var shown = pane.mode === "type" ? [pane.editing] : Search.rank(all, e => pane.score(e));
			// Typed on the first page: the two that live in Actions are found too.
			var pages = pane.mode === "browse" && pane.section === "" ? pane.actionsPages.filter(p => Search.matchScore([[p.label, 0]], pane.q) !== -1) : [];
			return pages.concat(shown.map(e => ({
				label: e.label,
				subtitle: pane.section === "" && pane.mode === "browse" ? e.group : "",
				tooltip: pane.mode === "browse" ? pane.tooltip(e) : "",
				heading: pane.q !== "" || pane.mode !== "browse" ? "" : pane.section === "changed" ? e.group : e.sub,
				lineIcon: e.icon,
				setting: e,
				run: () => {
					pane.enter(e);
					return false;
				}
			})));
		}

		emptyText: !Settings.loaded ? "Loading settings…" : pane.section === "changed" && pane.q === "" ? "Nothing changed here" : "Nothing matches"
	}
}
