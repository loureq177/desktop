pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// What the shell asks of Hyprland: Lua dispatches, strings through quote(); apps
// start through Hyprland, with the session's environment.
Singleton {
	id: root

	// The special workspaces open now, by name: Quickshell gives all specials one id,
	// so Hyprland.workspaces cannot tell them apart.
	property var specials: []
	// The other workspaces, { id, monitor, hasFullscreen } by id.
	property var workspaces: []

	// A fullscreen window on that screen's workspace, as far as is known yet.
	function fullscreenOn(screen): bool {
		// Quickshell's own id of the focused one is right, and at once.
		var id = Hyprland.monitorFor(screen)?.activeWorkspace?.id ?? -1;
		return workspaces.find(w => w.id === id)?.hasFullscreen ?? false;
	}

	// Called once the reload being run is done.
	property var afterReload: []
	property bool reloadAgain: false

	// Hyprland reads its config again and power-save puts its own back; then `done`.
	// One asked for meanwhile runs after, so it reads what was written since.
	function reload(done): void {
		if (done)
			afterReload = afterReload.concat([done]);
		if (reloader.running)
			reloadAgain = true;
		else
			reloader.running = true;
	}

	// A Lua string literal.
	function quote(text: string): string {
		return '"' + text.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"';
	}

	function dispatch(lua: string): void {
		Hyprland.dispatch(lua);
	}

	// argv as one line for sh.
	function shellLine(argv: var): string {
		return argv.map(a => "'" + String(a).replace(/'/g, "'\\''") + "'").join(" ");
	}

	// A command line as argv, run in `dir` when it is given. Untyped: a missing
	// `string` argument arrives as "undefined".
	function exec(argv: var, dir): void {
		var line = shellLine(argv);
		if (dir)
			line = "cd '" + String(dir).replace(/'/g, "'\\''") + "' && exec " + line;
		dispatch("hl.dsp.exec_cmd(" + quote(line) + ")");
	}

	function toggleSpecial(name: string): void {
		dispatch("function() require(\"hyprland.specials\").toggle(" + quote(name) + ") end");
	}

	function focusWorkspace(id: int): void {
		dispatch("hl.dsp.focus({ workspace = " + id + " })");
	}

	// The window of an app, by its class (any case).
	function focusApp(appClass: string): void {
		var regex = "^(?i)" + appClass.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$";
		dispatch("hl.dsp.focus({ window = " + quote("class:" + regex) + " })");
	}

	// Moving the cursor to where it already is hands the pointer to whatever lies under it.
	// follow_mouse 2 for that moment: the keyboard stays, a pointer at rest has chosen nothing.
	function refreshPointer(): void {
		dispatch("function() local was, c = hl.get_config(\"input.follow_mouse\"), hl.get_cursor_pos() hl.config({ input = { follow_mouse = 2 } }) hl.dispatch(hl.dsp.cursor.move({ x = c.x, y = c.y })) hl.config({ input = { follow_mouse = was } }) end");
	}

	// Closes the windows of special `name`, which removes it.
	function closeSpecial(name: string): void {
		dispatch("function() for _, w in ipairs(hl.get_windows({ workspace = " + quote("special:" + name) + " })) do hl.dispatch(hl.dsp.window.close({ window = w })) end end");
	}

	// Asked again after each event that may change them: one made before the shell
	// listened (the hidden Gmail) would be missed otherwise.
	Connections {
		target: Hyprland
		function onRawEvent(ev) {
			if (["createworkspacev2", "destroyworkspacev2", "changeworkspaceid", "moveworkspacev2", "openwindow", "closewindow", "movewindowv2", "fullscreen"].includes(ev.name))
				workspacesAsk.restart();
			// Quickshell keeps the old id of the workspace on a monitor until it is asked again.
			if (ev.name === "changeworkspaceid") {
				Hyprland.refreshWorkspaces();
				Hyprland.refreshMonitors();
			}
		}
	}

	// One ask at a time: an event during one asks again once it is done.
	Timer {
		id: workspacesAsk
		interval: 10
		onTriggered: {
			if (workspacesList.running)
				restart();
			else
				workspacesList.running = true;
		}
	}

	Process {
		id: workspacesList
		running: true
		command: ["hyprctl", "workspaces", "-j"]
		stdout: StdioCollector {
			onStreamFinished: {
				var all = [];
				try {
					all = JSON.parse(this.text);
				} catch (e) {
					return;
				}
				var special = w => String(w.name).startsWith("special:");
				var names = all.filter(special).map(w => w.name.slice(8));
				if (names.join("\n") !== root.specials.join("\n"))
					root.specials = names;
				var normal = all.filter(w => !special(w)).map(w => ({ id: w.id, monitor: w.monitor, hasFullscreen: w.hasfullscreen })).sort((a, b) => a.id - b.id);
				if (JSON.stringify(normal) !== JSON.stringify(root.workspaces))
					root.workspaces = normal;
			}
		}
	}

	Process {
		id: reloader
		command: ["sh", "-c", "hyprctl reload >/dev/null; \"$HOME/.local/bin/power-save\" --reapply >/dev/null 2>&1"]
		onExited: {
			if (root.reloadAgain) {
				root.reloadAgain = false;
				running = true;
				return;
			}
			var done = root.afterReload;
			root.afterReload = [];
			done.forEach(f => f());
		}
	}
}
