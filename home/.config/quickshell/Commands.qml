pragma Singleton
import Quickshell
import QtQuick

// What the desktop does: { id, name, desc, icon, run } and maybe active, confirm, alert,
// tint, group, keywords (synonyms), bind (its key, by description); run returning false keeps
// the launcher.
Singleton {
	id: root

	readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

	// A script of ~/.local/bin, with its arguments.
	function script(commandLine: string): void {
		Hypr.exec(["sh", "-c", root.bin + commandLine]);
	}

	function terminal(name: string): void {
		Hypr.exec(["ghostty", "+new-window", "-e", root.bin + name]);
	}

	// What a desktop entry runs, as argv.
	function entryCommand(entry: var): var {
		return entry.runInTerminal ? ["ghostty", "+new-window", "-e"].concat(entry.command) : entry.command;
	}

	// What picks from the screen starts once the panel that asked has slid
	// away, so that it is not in the picture.
	function capture(commandLine: string): void {
		Panels.close();
		Hypr.exec(["sh", "-c", "sleep " + (Theme.animNormal + 50) / 1000 + " && " + commandLine]);
	}

	// hyprshutdown closes every app, ends Hyprland, then runs `then`; mesa-egl (the
	// machine's own) keeps it off the sleeping NVIDIA GPU.
	function shutdown(then: string): void {
		const args = then ? ["hyprshutdown", "--post-cmd", then] : ["hyprshutdown"];
		Hypr.exec(["sh", "-c", 'if [ -x "$0" ]; then exec "$0" "$@"; fi; exec "$@"', root.bin + "mesa-egl", ...args]);
	}

	function open(panel: string, mode): bool {
		Panels.open(panel, mode);
		return false;
	}

	function get(id: string): var {
		return all.find(c => c.id === id) ?? null;
	}

	function run(id: string): void {
		get(id)?.run();
	}

	// The name the launcher lists a command under.
	function label(c: var): string {
		return c.active ? "Turn off " + c.name : c.name;
	}

	// The most used first: the "/" list shows them in this order, and a name
	// that matches two of them picks the first.
	readonly property var all: (Modes.recording ? [
		{ id: "record", group: "capture", name: "Stop recording", desc: "Save the screen recording", icon: "circle-stop", alert: true, run: () => script("record-screen") }
	] : [
		{ id: "record", group: "capture", name: "Record screen", desc: "An area, a window or a monitor", icon: "video", keywords: "video", run: () => capture(bin + "record-screen") },
		{ id: "record-mic", group: "capture", name: "Record screen with microphone", desc: "Your voice mixed in", icon: "mic", run: () => capture(bin + "record-screen --mic") },
		{ id: "record-cam", group: "capture", name: "Record screen with microphone and camera", desc: "Your voice and a camera overlay", icon: "webcam", keywords: "webcam", run: () => capture(bin + "record-screen --mic --cam") }
	]).concat([
		{ id: "screenshot", group: "capture", bind: "Capture: Screenshot", name: "Screenshot", desc: "An area, a window, or click for the screen", icon: "camera", run: () => capture(bin + "screenshot region") },
		{ id: "dictation", group: "capture", bind: "Capture: Dictation", name: "Dictation", desc: "Types what you say", icon: "audio-lines", active: Modes.dictation !== "", keywords: "speech voice", run: () => script("dictation") },
		{ id: "picker", group: "capture", name: "Color picker", desc: "Copies the hex value", icon: "pipette", run: () => capture("hyprpicker -a --notify") },
		{ id: "ocr", group: "capture", name: "OCR", desc: "Copies text from the screen", icon: "scan-text", run: () => capture(bin + "ocr") },

		{ id: "dnd", group: "modes", name: "Do not disturb", desc: "Silences notifications", icon: "bell-off", active: Notifications.dnd, tint: Theme.warning, keywords: "dnd", run: () => { Notifications.dnd = !Notifications.dnd; } },
		{ id: "nightlight", group: "modes", name: "Night light", desc: "Turns on at 8 PM", icon: "moon", active: Modes.nightLight, tint: Theme.warning, keywords: "blue light", run: () => Modes.toggleNightLight() },
		{ id: "awake", group: "modes", name: "Keep awake", desc: "The screen stays on", icon: "coffee", active: Modes.awake, keywords: "caffeine", run: () => script("awake-toggle") },
		{ id: "powersave", group: "modes", name: "Battery saver", desc: "60 Hz, dimmer, fewer effects", icon: "leaf", active: Modes.powerSave, tint: Theme.accentGreen, keywords: "power save", run: () => script("power-save") },
		...(Modes.batteryCareSupported ? [
			{ id: "batterycare", group: "modes", name: "Battery care", desc: "Stops charging short of full", icon: "battery-medium", active: Modes.batteryCare, tint: Theme.accentGreen, keywords: "charge limit", run: () => script("battery-care") }
		] : []),

		{ id: "wifi", group: "connections", name: "Wi-Fi", desc: "Networks", icon: "wifi", keywords: "wifi internet", run: () => open("actions", "wifi") },
		{ id: "bluetooth", group: "connections", name: "Bluetooth", desc: "Devices", icon: "bluetooth", keywords: "headphones", run: () => open("actions", "bluetooth") },

		{ id: "windows", group: "system", bind: "Essential: Open windows", name: "Open windows", desc: "Every window, on any workspace", icon: "app-window", keywords: "overview apps switcher running", run: () => open("launcher", "windows") },
		{ id: "settings", group: "system", bind: "System & Tools: Settings", name: "Settings", desc: "Hyprland and the look", icon: "settings", keywords: "config preferences", run: () => open("launcher", "settings") },
		{ id: "clipboard", group: "system", bind: "System & Tools: Clipboard history", name: "Clipboard", desc: "What was copied", icon: "clipboard", keywords: "history paste", run: () => open("launcher", "clipboard") },
		{ id: "emoji", group: "system", bind: "System & Tools: Emojis", name: "Emoji", desc: "Pick one to paste", icon: "smile", keywords: "smiley", run: () => open("launcher", "emoji") },
		{ id: "keys", group: "system", bind: "System & Tools: Keybindings", name: "Keybindings", desc: "See, change, remove or add keys", icon: "keyboard", keywords: "shortcuts hotkeys binds", run: () => open("launcher", "keys") },
		{ id: "actions", group: "system", bind: "System & Tools: Actions", name: "Actions", desc: "Volume, brightness and the switches", icon: "sliders-horizontal", keywords: "quick settings", run: () => open("actions", "") },
		{ id: "weather", group: "system", bind: "System & Tools: Weather", name: "Weather", desc: "The forecast", icon: "cloud-sun", run: () => open("weather", "") },
		{ id: "notifications", group: "system", bind: "Notifications: Toggle notification center", name: "Notifications", desc: "The notification center", icon: "bell", run: () => open("notifications", "") },
		{ id: "sysupdate", group: "system", name: "System update", desc: "Upgrades the packages", icon: "package", keywords: "sysupdate", run: () => terminal("sysupdate") },
		{ id: "sysclean", group: "system", name: "System cleanup", desc: "Caches, orphaned packages, the trash", icon: "trash", keywords: "sysclean", run: () => terminal("sysclean") },

		{ id: "lock", group: "session", bind: "Session: Lock system", name: "Lock", desc: "Locks the screen", icon: "lock", run: () => Hypr.exec(["loginctl", "lock-session"]) },
		{ id: "suspend", group: "session", name: "Suspend", desc: "Lock and sleep", icon: "moon", run: () => Hypr.exec(["sh", "-c", "loginctl lock-session && systemctl suspend"]) },
		{ id: "logout", group: "session", name: "Log out", desc: "Close the apps, end the session", icon: "log-out", confirm: "log out", keywords: "logout exit", run: () => shutdown("") },
		{ id: "reboot", group: "session", name: "Reboot", desc: "Close the apps, restart", icon: "rotate-cw", confirm: "reboot", run: () => shutdown("systemctl reboot --no-wall") },
		{ id: "poweroff", group: "session", name: "Power off", desc: "Close the apps, shut down", icon: "power", confirm: "power off", keywords: "shutdown", run: () => shutdown("systemctl poweroff --no-wall") }
	])
}
