pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick

// What the shell asks of Hyprland. A dispatch is Lua (hl.dsp, as in
// hyprland.lua), and every string goes into it through quote(). What the user
// starts runs through Hyprland too: it gets the session's environment instead
// of the shell's, and is no child of the shell.
Singleton {
	id: root

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
}
