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

	// A Lua string literal.
	function quote(text: string): string {
		return '"' + text.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"';
	}

	function dispatch(lua: string): void {
		Hyprland.dispatch(lua);
	}

	// A command line as argv, run in `dir` when it is given. Untyped: a missing
	// `string` argument arrives as "undefined".
	function exec(argv: var, dir): void {
		var line = argv.map(a => "'" + String(a).replace(/'/g, "'\\''") + "'").join(" ");
		if (dir)
			line = "cd '" + String(dir).replace(/'/g, "'\\''") + "' && exec " + line;
		dispatch("hl.dsp.exec_cmd(" + quote(line) + ")");
	}

	function toggleSpecial(name: string): void {
		dispatch("hl.dsp.workspace.toggle_special(" + quote(name) + ")");
	}

	function focusWorkspace(id: int): void {
		dispatch("hl.dsp.focus({ workspace = " + id + " })");
	}

	// The window of an app, by its class (any case).
	function focusApp(appClass: string): void {
		var regex = "^(?i)" + appClass.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$";
		dispatch("hl.dsp.focus({ window = " + quote("class:" + regex) + " })");
	}

	// A selector that matches nothing lands on the focused window: what is not
	// an address closes nothing.
	function closeWindow(address: string): void {
		var hex = address.startsWith("0x") ? address : "0x" + address;
		if (/^0x[0-9a-f]+$/i.test(hex))
			dispatch("hl.dsp.window.close({ window = " + quote("address:" + hex) + " })");
	}

	// Moving the cursor to where it already is hands the pointer to whatever
	// lies under it.
	function refreshPointer(): void {
		dispatch("hl.dsp.cursor.move({ x = hl.get_cursor_pos().x, y = hl.get_cursor_pos().y })");
	}

	// Closes the windows of special `name`, which removes it; hyprctl, as Quickshell
	// knows a special only by the shared id.
	function closeSpecial(name: string): void {
		closer.command = ["sh", "-c", 'hyprctl clients -j | jq -r --arg ws "special:$1" \'.[] | select(.workspace.name == $ws) | .address\'', "sh", name];
		closer.running = true;
	}

	// Asked again after each event that may change them: one made before the shell
	// listened (the hidden Gmail) would be missed otherwise.
	Connections {
		target: Hyprland
		function onRawEvent(ev) {
			if (["createworkspacev2", "destroyworkspacev2", "openwindow", "closewindow", "movewindowv2"].includes(ev.name))
				specialsAsk.restart();
		}
	}

	// One ask at a time: an event during one asks again once it is done.
	Timer {
		id: specialsAsk
		interval: 50
		onTriggered: {
			if (specialsList.running)
				restart();
			else
				specialsList.running = true;
		}
	}

	Process {
		id: specialsList
		running: true
		command: ["sh", "-c", "hyprctl workspaces -j | jq -r '.[].name | select(startswith(\"special:\"))'"]
		stdout: StdioCollector {
			onStreamFinished: {
				var names = this.text.split("\n").filter(n => n !== "").map(n => n.slice(8));
				if (names.join("\n") !== root.specials.join("\n"))
					root.specials = names;
			}
		}
	}

	Process {
		id: closer
		stdout: StdioCollector {
			onStreamFinished: this.text.split("\n").filter(a => a !== "").forEach(a => root.closeWindow(a))
		}
	}
}
