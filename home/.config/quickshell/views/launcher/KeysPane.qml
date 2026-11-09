import "../.."
import "../../widgets"
import "../../Search.js" as Search
import Quickshell
import QtQuick

// Every bind and shell key (Keybinds): in sections when nothing is typed, else ranked.
// Enter on a bind takes new keys (only the modifiers for a line of several), Delete
// twice removes it, blue was set here, Ctrl+R gives the config's back; the first row
// adds a new one, an app or a command.
LauncherPane {
	id: pane

	readonly property string q: query.trim()
	// Picking what a new key runs.
	property bool adding: false
	// The line taking new keys, and the modifiers held for it so far.
	property var editing: null
	property int held: 0
	// The row to select again once Hyprland's binds come back, or -1; or by its id.
	property int kept: -1
	property string keptId: ""

	icon: editing ? "pencil" : adding ? "plus" : "keyboard"
	placeholder: adding ? "An app, or a command to run…" : "Search keys…"
	preferredHeight: list.preferredHeight
	error: Keybinds.lastError

	function step(delta: int, repeat: bool): void {
		list.step(delta, repeat);
	}

	function activate(): void {
		list.activate();
	}

	function back(): bool {
		if (editing)
			stop();
		else if (adding)
			leaveAdding();
		else
			return false;
		return true;
	}

	function resetValue(): void {
		var line = list.items[list.currentIndex]?.line;
		if (!line)
			return;
		if (Keybinds.saved[line.id] !== undefined && !Keybinds.custom(line))
			kept = list.currentIndex;
		Keybinds.reset(line);
	}

	// The second press within its time removes it.
	function removeValue(): void {
		var line = list.items[list.currentIndex]?.line;
		if (!line || line.removed || editing || adding)
			return;
		if (!removal.ask(line.id))
			return;
		kept = list.currentIndex;
		Keybinds.remove(line);
	}

	function opened(): void {
		Keybinds.lastError = "";
		removal.reset();
		adding = false;
		list.rewind();
	}

	function closed(): void {
		stop();
		removal.reset();
		adding = false;
	}

	// Where the row comes from, then what can be done with it: each in that form.
	function tooltip(e: var): string {
		if (e.removed)
			return "Removed here\nEnter or Ctrl+R: bring it back";
		if (!e.editable)
			return "The shell's own\nIt cannot be changed here";
		var added = Keybinds.custom(e);
		var keys = e.modsOnly ? "Enter: new modifiers, " + e.label + " stay" : "Enter: new keys";
		return (added ? "Added here: " + Keybinds.saved[e.id].run : Keybinds.changed(e) ? "Changed here" : "From the config") + "\n"
			+ [keys, Keybinds.changed(e) && !added ? "Ctrl+R: back to the config's" : "", "Delete twice: remove"].filter(t => t !== "").join("  ·  ");
	}

	// The line icon of a key: what it is pressed with.
	function keyIcon(category: string): string {
		return category === "Mouse" ? "mouse" : category === "Gestures" ? "hand" : category === "Removed" ? "x" : "keyboard";
	}

	function startAdding(): void {
		removal.reset();
		adding = true;
		Keybinds.lastError = "";
		pane.queryRequested("");
	}

	function leaveAdding(): void {
		adding = false;
		pane.queryRequested("");
	}

	function pick(name: string, run: string): void {
		var line = Keybinds.newLine(name, run);
		if (line)
			start(line);
	}

	// The keys go to the catcher, Hyprland's binds rest until stop().
	function start(line: var): void {
		if (!line.editable)
			return;
		Keybinds.lastError = "";
		removal.reset();
		if (!editing)
			Keybinds.capture(true);
		held = 0;
		list.keepIndex(() => editing = line);
		giveUp.restart();
		catcher.forceActiveFocus();
	}

	function stop(): void {
		if (!editing)
			return;
		list.keepIndex(() => editing = null);
		giveUp.stop();
		Keybinds.capture(false);
		pane.queryRequested(query);
	}

	function pressed(event: var): void {
		var bit = Keybinds.modifierBit(event.key);
		var mask = Keybinds.maskOf(event.modifiers);
		if (bit) {
			held = mask | bit;
			return;
		}
		if (event.key === Qt.Key_Escape && mask === 0) {
			stop();
			return;
		}
		var key = Keybinds.keyName(event.key);
		if (event.isAutoRepeat || (editing.modsOnly && mask === 0))
			return;
		// Alone, a key that types would stop typing it everywhere.
		if ((mask & ~1) === 0 && key !== "" && !/^(F\d+|print|Insert|Delete|Home|End|Page_Up|Page_Down)$/.test(key)) {
			Keybinds.lastError = "That key types: it needs SUPER, CTRL or ALT with it";
			return;
		}
		var line = editing;
		var index = list.currentIndex;
		stop();
		if (key === "") {
			Keybinds.lastError = "That key cannot be bound here";
		} else if (Keybinds.rebind(line, mask, line.modsOnly ? "" : key)) {
			if (line.run) {
				keptId = line.id;
				adding = false;
				pane.queryRequested("");
			} else {
				kept = index;
			}
		}
	}

	onQueryChanged: {
		removal.reset();
		list.reset();
	}

	Confirm {
		id: removal
	}

	Connections {
		target: Keybinds
		function onEntriesChanged() {
			var index = pane.keptId !== "" ? list.items.findIndex(it => it.line?.id === pane.keptId) : pane.kept;
			pane.kept = -1;
			pane.keptId = "";
			if (index >= 0)
				Qt.callLater(() => list.currentIndex = Math.min(index, list.count - 1));
		}
	}

	// Hyprland gives its binds back after 30 s: the shell lets go a little sooner.
	Timer {
		id: giveUp
		interval: 25000
		onTriggered: {
			pane.stop();
			Keybinds.lastError = "No keys pressed, the bind stays as it was";
		}
	}

	Item {
		id: catcher
		onActiveFocusChanged: {
			if (!activeFocus)
				pane.stop();
		}
		Keys.onPressed: event => {
			event.accepted = true;
			pane.pressed(event);
		}
		Keys.onReleased: event => {
			event.accepted = true;
			pane.held = Keybinds.maskOf(event.modifiers) & ~Keybinds.modifierBit(event.key);
		}
	}

	ResultList {
		id: list
		anchors.fill: parent

		editingChord: pane.editing ? Keybinds.chordOf(pane.held, pane.editing.modsOnly ? pane.editing.label : "…") : ""
		armedId: removal.armed
		armedText: "Press Delete again to remove"
		items: {
			// A new line has no row of its own yet.
			if (pane.editing?.run)
				return [{
					label: pane.editing.action,
					subtitle: "Press the new keys · Esc leaves it",
					editing: true,
					lineIcon: "pencil",
					changed: true,
					chord: "…",
					run: () => false
				}];
			if (pane.adding) {
				var typed = pane.q === "" ? [] : [{
					label: pane.q,
					lineIcon: "terminal",
					run: () => {
						pane.pick(pane.q, pane.q);
						return false;
					}
				}];
				var apps = Search.rank(DesktopEntries.applications.values ?? [], e => Search.appScore(e, pane.q), (a, b) => a.name.localeCompare(b.name));
				return typed.concat(apps.map(e => ({
					label: e.name || e.id,
					subtitle: e.genericName || "",
					icon: e.icon,
					run: () => {
						pane.pick(e.name || e.id, Hypr.shellLine(Commands.entryCommand(e)));
						return false;
					}
				})));
			}
			var rows = pane.q !== "" ? [] : [{
				label: "Add a new key",
				tooltip: "Your own\nEnter: pick an app or type a command, then press its keys",
				lineIcon: "plus",
				run: () => {
					pane.startAdding();
					return false;
				}
			}];
			return rows.concat(Search.rank(Keybinds.entries, e => Search.matchScore([[e.action, 0], [e.chord, 4], [e.category, 7]], pane.q)).map(e => {
				var now = pane.editing?.id === e.id && e.editable;
				var changed = Keybinds.changed(e);
				return {
					label: e.action,
					subtitle: now ? (e.modsOnly ? "Hold the new modifiers, press a key · Esc leaves it" : "Press the new keys · Esc leaves it")
						: e.removed ? (pane.q === "" ? e.from : "Removed from " + e.from)
						: pane.q === "" ? "" : e.category,
					editing: now,
					heading: pane.q === "" ? e.category : "",
					lineIcon: now ? "pencil" : pane.keyIcon(e.category),
					chord: e.chord,
					changed: changed || now,
					tooltip: now ? "" : () => pane.tooltip(e),
					line: e.editable || e.removed ? e : undefined,
					armId: e.editable ? e.id : "",
					run: () => {
						if (e.removed) {
							pane.kept = list.currentIndex;
							Keybinds.reset(e);
						} else {
							pane.start(e);
						}
						return false;
					}
				};
			}));
		}

		emptyText: Keybinds.loaded ? "Nothing matches" : "Loading keys…"
	}
}
