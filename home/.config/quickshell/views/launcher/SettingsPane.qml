import "../.."
import "../../Search.js" as Search
import QtQuick

// Pages as other systems have them (Settings.pages), typing searches them all: Enter edits,
// ←/→ steps or goes in and out, blue was set here, Ctrl+R gives it back to the config, Esc steps out. What the
// picked setting does is said under the list. The screens' arrangement is a picture of its own.
LauncherPane {
	id: pane

	// "browse" the settings, "choose" from the choices of `editing`, "type" a value for it,
	// or "arrange" the screens.
	property string mode: "browse"
	property var editing: null
	// The page browsed: "" the first, a page's key, or "changed": what was set here.
	property string section: ""
	// Where browsing was, to come back to.
	property string browseQuery: ""
	property int browseIndex: 0

	readonly property string q: query.trim()
	// Choices that are pictures (wallpapers): big tiles, three to a row.
	readonly property bool pictures: mode === "choose" && editing.choices.some(c => c.thumb)
	readonly property var current: mode === "browse" ? (list.items[list.currentIndex]?.setting ?? null) : editing
	// Hidden, not made: each volume or brightness step makes Settings.entries again.
	readonly property var changedEntries: visible ? Settings.entries.filter(e => Settings.changed(e)) : []
	readonly property string sectionLabel: section === "changed" ? "Changed settings" : Settings.page(section)?.label ?? ""

	icon: mode === "browse" ? "settings" : mode === "arrange" ? "monitor" : "pencil"
	grid: mode !== "type"
	placeholder: mode === "arrange" ? (arrangement.dirty ? "Enter applies the arrangement, Esc leaves it as it was" : "Arrange the screens")
		: mode === "choose" ? "Pick " + editing.label.toLowerCase() + (editing.customHint ? ", " + editing.customHint : "") + "…"
		: mode === "type" ? "A value for " + editing.label.toLowerCase() + range(editing)
		: !Settings.loaded ? "Loading settings…"
		: section !== "" ? "Search " + sectionLabel.toLowerCase() + "…"
		: "Search settings…"
	preferredHeight: mode === "arrange" ? 380 : list.preferredHeight
	error: Settings.lastError
	footer: mode === "arrange" ? "" : list.currentTip
	// The lines under the list stay while a page is open: the list does not jump from row to row.
	keepFooter: mode === "browse" && (section !== "" || q !== "")
	canGoBack: mode !== "browse" || section !== ""

	function score(e: var): int {
		return Search.settingScore(e, q, true);
	}

	// What it does; in Advanced also its name and default; and how a change goes back.
	function tooltip(e: var): string {
		var more = [];
		if (e.section === "advanced" && e.source === "hyprland")
			more.push(e.name + range(e) + " · default " + Settings.display(Object.assign({}, e, { value: e.defaultValue })));
		else if (e.section === "advanced" && e.source === "ui")
			more.push(e.name + " in ui.toml");
		if (Settings.changed(e))
			more.push("Changed here: Ctrl+R puts it back");
		return [e.desc ?? "", more.join("  ·  ")].filter(t => t !== "").join("\n");
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
		// Among pictures, ← out from the first one.
		if (list.items[list.currentIndex]?.tiles && (delta > 0 || list.tileIndex > 0)) {
			list.stepTile(delta);
			return;
		}
		// A value steps; elsewhere → goes in (a page, the choices, a value to type), ← out.
		var e = mode === "browse" ? current : null;
		if (e && !e.stepless && Settings.stepped(e, delta) !== undefined) {
			list.keepIndex(() => Settings.set(e, Settings.stepped(e, delta)));
			return;
		}
		if (repeat)
			return;
		var row = list.items[list.currentIndex];
		if (delta < 0)
			back();
		else if (row && !row.confirm)
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

	// Its tab clicked again: the first list.
	function home(): bool {
		if (mode === "browse" && section === "" && q === "")
			return false;
		mode = "browse";
		editing = null;
		openSection("");
		return true;
	}

	// Into a page (its own list, its own search), or back out to where it was opened from.
	// Back on the first list, the page left is picked again: found by its key, as "Changed
	// settings" may have come or gone meanwhile.
	function openSection(key: string): void {
		var from = section;
		section = key;
		pane.queryRequested("");
		Qt.callLater(() => list.currentIndex = key !== "" ? 0 : Math.max(0, list.items.findIndex(r => r.pageKey === from)));
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
		// Pictures open on the one set now.
		var now = e.kind === "enum" ? e.choices.findIndex(c => c.thumb && c.value === e.value) : -1;
		if (now > 0)
			Qt.callLater(() => {
				list.currentIndex = Math.floor(now / list.tilesPerRow);
				list.tileIndex = now % list.tilesPerRow;
			});
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

	function page(label: string, icon: string, run: var): var {
		return { label: label, lineIcon: icon, run: run };
	}

	function openPage(key: string): var {
		return () => {
			pane.openSection(key);
			return false;
		};
	}

	// The pages, what was changed here first.
	function pageRows(): var {
		var rows = Settings.pages.map(p => Object.assign(page(p.label, p.icon, openPage(p.key)), { pageKey: p.key }));
		if (changedEntries.length > 0)
			rows.unshift(Object.assign(page("Changed settings", "pencil", openPage("changed")), { pageKey: "changed", subtitle: String(changedEntries.length) }));
		return rows;
	}

	// What a page has besides its settings, when nothing is typed.
	function extraRows(): var {
		if (section === "changed" && changedEntries.length > 0)
			return [Object.assign(page("Undo all", "rotate-cw", () => {
				Settings.resetAll();
				return false;
			}), { confirm: "undo all" })];
		if (section === "keyboard")
			return [page("Shortcuts", "keyboard", () => {
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
		onApplyRequested: pane.activate()
		onCancelRequested: pane.leave()
	}

	ResultList {
		id: list
		anchors.fill: parent
		visible: pane.mode !== "arrange"
		tilesPerRow: pane.pictures ? 3 : 6
		// A 16:9 picture as wide as a third, its name under it.
		tileHeight: pane.pictures ? Math.round((width / 3 - 16) * 9 / 16) + 44 : 84

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
				var made = v => ({ label: pane.editing.customLabel ? pane.editing.customLabel(v) : String(v), value: v, swatch: pane.editing.presets || pane.editing.custom && typeof v === "string" ? v : undefined });
				var choices = pane.editing.choices.concat(typed !== undefined && !pane.editing.choices.some(c => c.value === typed) ? [made(typed)] : []);
				var ranked = Search.rank(choices, c => typed !== undefined && c.value === typed ? -1000 : Search.matchScore([[String(c.label), 0]], pane.q));
				var picks = ranked.map(c => ({
					label: String(c.label),
					// The one set now: a check, or a word where a picture takes the icon's place.
					subtitle: (c.thumb || c.swatch) && c.value === pane.editing.value ? "Now" : "",
					lineIcon: c.thumb || c.swatch ? "" : c.value === pane.editing.value ? "check" : "",
					thumb: c.thumb,
					swatch: c.swatch,
					run: () => {
						pane.pick(c.value);
						return false;
					}
				}));
				if (!pane.pictures)
					return picks;
				var lines = [];
				for (var i = 0; i < picks.length; i += tilesPerRow)
					lines.push({ label: "", tiles: picks.slice(i, i + tilesPerRow) });
				return lines;
			}
			if (pane.mode === "browse" && pane.q === "" && pane.section === "")
				return pane.pageRows();
			var all = pane.section === "" ? Settings.entries
				: pane.section === "changed" ? pane.changedEntries
				: Settings.pageEntries(pane.section);
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

		emptyText: !Settings.loaded ? "Loading settings…" : pane.section === "changed" && pane.q === "" ? "Nothing changed" : "Nothing matches"
	}
}
