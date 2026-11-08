import "../.."
import "../../Search.js" as Search
import QtQuick

// Pages as other systems have them (Settings.pages), typing searches them all: Enter edits,
// ←/→ steps, blue was set here, Ctrl+R gives it back to the config, Esc steps out. What a
// setting does shows on hover. The screens' arrangement is a picture of its own.
LauncherPane {
	id: pane

	// "browse" the settings, "choose" from the choices of `editing`, "type" a value for it,
	// or "arrange" the screens.
	property string mode: "browse"
	property var editing: null
	// The page browsed: "" the first, a page's key, or "changed": what was set here.
	property string section: ""
	property int sectionIndex: 0
	// Where browsing was, to come back to.
	property string browseQuery: ""
	property int browseIndex: 0

	readonly property string q: query.trim()
	readonly property var current: mode === "browse" ? (list.items[list.currentIndex]?.setting ?? null) : editing
	// Hidden, not made: each volume or brightness step makes Settings.entries again.
	readonly property var changedEntries: visible ? Settings.entries.filter(e => Settings.changed(e)) : []
	readonly property string sectionLabel: section === "changed" ? "Changed here" : Settings.page(section)?.label ?? ""

	icon: mode === "browse" ? "settings" : mode === "arrange" ? "monitor" : "pencil"
	grid: mode === "browse" || mode === "arrange"
	placeholder: mode === "arrange" ? (arrangement.dirty ? "Enter applies the arrangement, Esc leaves it as it was" : "Arrange the screens")
		: mode === "choose" ? "Pick " + editing.label.toLowerCase() + "…"
		: mode === "type" ? "A value for " + editing.label.toLowerCase() + range(editing)
		: !Settings.loaded ? "Loading settings…"
		: section !== "" ? "Search " + sectionLabel.toLowerCase() + "…"
		: "Search " + Settings.entries.length + " settings…"
	preferredHeight: mode === "arrange" ? 380 : list.preferredHeight
	error: Settings.lastError

	function score(e: var): int {
		return Search.settingScore(e, q, true);
	}

	// What it does, its name and default, and how it changes.
	function tooltip(e: var): string {
		if (e.source === "ui")
			return e.name + " in ui.toml, for the whole desktop: the shell restarts with it";
		if (e.source !== "hyprland")
			return e.desc + (Settings.changed(e) ? "\nSet here: Ctrl+R gives it back to the config" : "");
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
		if (mode === "arrange")
			arrangement.move(0, delta);
		else
			list.step(delta, repeat);
	}

	function tab(delta: int, repeat: bool): void {
		if (mode === "arrange")
			arrangement.choose(delta);
		else
			list.step(delta, repeat);
	}

	function stepColumn(delta: int, repeat: bool): void {
		if (mode === "arrange") {
			arrangement.move(delta, 0);
			return;
		}
		var e = current;
		if (!e || e.source === "ui" || e.stepless)
			return;
		list.keepIndex(() => Settings.set(e, Settings.stepped(e, delta)));
	}

	// Ctrl + L goes in (a page, a list of choices, a value to type), Ctrl + H back out; the
	// arrows keep stepping values, and move the screens of the arrangement.
	function sideways(delta: int, repeat: bool): void {
		if (mode === "arrange") {
			arrangement.move(delta, 0);
			return;
		}
		if (repeat)
			return;
		if (delta < 0) {
			back();
			return;
		}
		var row = list.items[list.currentIndex];
		if (mode === "choose" || (mode === "browse" && row && !row.confirm && row.setting?.kind !== "bool"))
			list.activate();
	}

	function activate(): void {
		if (mode !== "arrange") {
			list.activate();
			return;
		}
		if (arrangement.dirty) {
			// The top left at 0,0, as Hyprland's "auto" would start.
			var x0 = Math.min(...arrangement.draft.map(d => d.x)), y0 = Math.min(...arrangement.draft.map(d => d.y));
			var places = {};
			for (const d of arrangement.draft)
				places[d.output] = (d.x - x0) + "x" + (d.y - y0);
			Settings.arrange(places);
		}
		leave();
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

	// Into a page (its own list, its own search), or back out to where it was opened from.
	function openSection(key: string): void {
		var index = key === "" ? sectionIndex : 0;
		if (key !== "" && section === "")
			sectionIndex = list.currentIndex;
		section = key;
		pane.queryRequested("");
		Qt.callLater(() => list.currentIndex = index);
	}

	// From the apps' search: the setting found by its name and edited, Esc back to that list.
	function edit(e: var): void {
		pane.queryRequested(e.label);
		Qt.callLater(() => {
			var i = list.items.findIndex(it => it.setting?.id === e.id);
			if (i === -1)
				return;
			list.currentIndex = i;
			enter(list.items[i].setting);
		});
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
		if (e.kind === "arrange") {
			arrangement.load();
			mode = "arrange";
			Settings.lastError = "";
			pane.queryRequested("");
			return;
		}
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

	// Each page with what it holds, what was changed here first.
	function pageRows(): var {
		var screens = Settings.monitors.map(m => m.width + "x" + m.height + " · " + Math.round(m.refreshRate) + " Hz").join(", ");
		var idle = Settings.idleEntries;
		var says = {
			displays: screens,
			sound: Audio.sink?.description ?? "",
			appearance: "Colours, fonts, theme, blur, animations",
			desktop: "Hot corners, top bar, clock",
			windows: "Layouts, groups, resizing",
			keyboard: "Layout, repeat, shortcuts",
			mouse: "Speed, scrolling, touchpad, gestures",
			idle: idle.length === 4 ? "Locks after " + Settings.duration(idle[0].value) + ", sleeps after " + Settings.duration(idle[3].value) : "",
			advanced: Settings.entries.filter(e => e.section === "advanced").length + " more of Hyprland's options"
		};
		var rows = Settings.pages.map(p => {
			var n = changedEntries.filter(e => e.section === p.key).length;
			return page(p.label, says[p.key] + (n > 0 ? " · " + n + " changed" : ""), p.icon, openPage(p.key));
		});
		if (changedEntries.length > 0)
			rows.unshift(page("Changed here", changedEntries.length + (changedEntries.length === 1 ? " setting" : " settings") + " set over the config", "pencil", openPage("changed")));
		return rows;
	}

	// What a page has besides its settings, when nothing is typed.
	function extraRows(): var {
		if (section === "changed" && changedEntries.length > 0)
			return [{
				label: "Undo all",
				subtitle: "Every one of them back to the config's",
				lineIcon: "rotate-cw",
				confirm: true,
				run: () => {
					Settings.resetAll();
					return false;
				}
			}];
		if (section === "keyboard")
			return [page("Shortcuts", "Every key and what it does; Enter changes one", "keyboard", () => {
				Panels.open("launcher", "keys");
				return false;
			})];
		return [];
	}

	onQueryChanged: {
		if (mode === "arrange" && query !== "")
			pane.queryRequested("");
		else if (mode !== "type")
			list.reset();
	}

	Arrangement {
		id: arrangement
		anchors.fill: parent
		visible: pane.mode === "arrange"
	}

	ResultList {
		id: list
		anchors.fill: parent
		visible: pane.mode !== "arrange"
		// How long the page is: settings run to hundreds.
		scrollBar: true

		// Displays and audio answer later than the keypress: a new model would go back to the top.
		onRowsChanged: {
			if (rows === null)
				return;
			var index = currentIndex;
			items = rows;
			currentIndex = Math.min(index, count - 1);
		}

		// Hidden, nothing is made: each step of the volume keys made the whole list again.
		readonly property var rows: {
			if (!pane.visible)
				return null;
			if (pane.mode === "choose") {
				var typed = pane.editing.custom ? pane.editing.custom(pane.q) : undefined;
				var choices = pane.editing.choices.concat(typed !== undefined && !pane.editing.choices.some(c => c.value === typed) ? [{ label: Math.round(typed * 100) + "%", value: typed }] : []);
				var ranked = Search.rank(choices, c => typed !== undefined && c.value === typed ? -1000 : Search.matchScore([[String(c.label), 0]], pane.q));
				return ranked.map(c => ({
					label: String(c.label),
					subtitle: c.value === pane.editing.value ? "now" : "",
					lineIcon: c.value === pane.editing.value ? "check" : "",
					run: () => {
						pane.pick(c.value);
						return false;
					}
				}));
			}
			if (pane.mode === "browse" && pane.q === "" && pane.section === "")
				return pane.pageRows();
			var all = pane.section === "" ? Settings.entries
				: pane.section === "changed" ? pane.changedEntries
				: Settings.entries.filter(e => e.section === pane.section);
			var shown = pane.mode === "type" || pane.mode === "arrange" ? [pane.editing] : Search.rank(all, e => pane.score(e));
			// On a page, with nothing typed, what it has besides its settings.
			var pages = pane.mode === "browse" && pane.section !== "" && pane.q === "" ? pane.extraRows() : [];
			return pages.concat(shown.map(e => ({
				label: e.label,
				subtitle: pane.section === "" && pane.mode === "browse" ? e.group : "",
				tooltip: pane.mode === "browse" ? () => pane.tooltip(e) : "",
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
