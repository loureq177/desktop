pragma Singleton
import Quickshell
import QtQuick

// What the desktop does, wherever the shell offers it: the launcher finds a
// command by name, the bar and the tiles of Actions run it by id. Each is
// { id, name, desc, icon, keywords, run } and maybe
//   bind     the description of the key bind that does the same
//   active   a switch's state: the launcher offers to turn it off
//   confirm  the verb of what runs on a second Enter only ("reboot")
//   alert    drawn in the critical colour; tint: its icon's colour
//   group    "capture" for the Capture page of Actions
// `run` returning false keeps the launcher open (it opened another panel).
Singleton {
	id: root

	readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

	// Without what the shell itself was started with (an EGL vendor, the
	// allocator's settings): what the shell starts picks its own. `env -C` sets
	// the working directory: execDetached takes no { command, workingDirectory }
	// object (quickshell 0.3.2 refuses it). The directory is untyped: a missing
	// `string` argument arrives as "undefined".
	function spawn(command: var, workingDirectory): void {
		var dir = workingDirectory ? ["-C", workingDirectory] : [];
		Quickshell.execDetached(["env", "-u", "__EGL_VENDOR_LIBRARY_FILENAMES", "-u", "MALLOC_CONF"].concat(dir, command));
	}

	// A script of ~/.local/bin, with its arguments.
	function script(commandLine: string): void {
		spawn(["sh", "-c", root.bin + commandLine]);
	}

	function terminal(name: string): void {
		spawn(["ghostty", "+new-window", "-e", root.bin + name]);
	}

	// What picks from the screen starts once the panel that asked is gone,
	// so it is not in the picture.
	function capture(commandLine: string): void {
		Panels.closeInstant();
		spawn(["sh", "-c", "sleep 0.15 && " + commandLine]);
	}

	function toggleSpecial(name: string): void {
		Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('" + name + "')"]);
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

	readonly property var captureCommands: all.filter(c => c.group === "capture")

	readonly property var all: [
		{ id: "clipboard", name: "Clipboard history", desc: "Paste something copied before", icon: "clipboard", bind: "Clipboard history", keywords: "clipboard paste copy schowek historia wklej", run: () => open("launcher", "clipboard") },
		{ id: "emoji", name: "Emoji", desc: "Insert an emoji", icon: "smile", bind: "Emojis", keywords: "emoji emotki smiley picker", run: () => open("launcher", "emoji") },
		{ id: "keys", name: "Keybindings", desc: "Every key and what it does", icon: "keyboard", bind: "Keybindings", keywords: "keys keybindings shortcuts help cheatsheet skróty klawisze pomoc", run: () => open("launcher", "keys") },
		{ id: "actions", name: "Actions", desc: "Volume, brightness, Wi-Fi, Bluetooth", icon: "layout-grid", bind: "Actions", keywords: "actions quick settings volume brightness ustawienia głośność jasność dźwięk", run: () => open("actions") },
		{ id: "wifi", name: "Wi-Fi", desc: "Networks", icon: "wifi", keywords: "wifi wi-fi network wireless internet sieć", run: () => open("actions", "wifi") },
		{ id: "bluetooth", name: "Bluetooth", desc: "Devices", icon: "bluetooth", keywords: "bluetooth headphones devices słuchawki urządzenia", run: () => open("actions", "bluetooth") },
		{ id: "notifications", name: "Notifications", desc: "Notification history", icon: "bell", bind: "Toggle notification center", keywords: "notifications history powiadomienia", run: () => open("notifications") },
		{ id: "dnd", name: "Do not disturb", desc: "Silence notifications", icon: "bell-off", active: Notifications.dnd, tint: Theme.warning, keywords: "dnd do not disturb quiet silence nie przeszkadzać cisza", run: () => { Notifications.dnd = !Notifications.dnd; } },
		{ id: "weather", name: "Weather", desc: "Forecast", icon: "cloud-sun", bind: "Weather", keywords: "weather forecast pogoda prognoza", run: () => open("weather") },
		{ id: "powersave", name: "Battery saver", desc: "60 Hz, dimmer, fewer effects", icon: "leaf", active: SystemStatus.powerSaveActive, tint: Theme.accentGreen, keywords: "battery saver power save 60hz oszczędzanie bateria", run: () => script("power-save") },
		{ id: "awake", name: "Keep awake", desc: "The screen stays on", icon: "coffee", active: SystemStatus.awakeActive, keywords: "keep awake caffeine inhibit idle sleep nie usypiaj", run: () => script("awake-toggle") },
		{ id: "wallpaper", name: "Next wallpaper", desc: "Change the background", icon: "image", bind: "Next wallpaper", keywords: "wallpaper background tapeta tło", run: () => script("wallpaper next") },

		{ id: "screenshot", group: "capture", name: "Screenshot", desc: "An area, a window, or click for the screen", icon: "camera", bind: "Screenshot", keywords: "screenshot capture region window full fullscreen zrzut ekranu cały", run: () => capture(bin + "screenshot region") }
	].concat(SystemStatus.recording ? [
		{ id: "record", group: "capture", name: "Stop recording", desc: "Save the screen recording", icon: "circle-stop", alert: true, keywords: "record screen video recording stop nagrywanie zatrzymaj", run: () => script("record-screen") }
	] : [
		{ id: "record", group: "capture", name: "Record screen", desc: "An area or a window", icon: "video", keywords: "record screen video recording nagraj ekran wideo nagrywanie", run: () => capture(bin + "record-screen") },
		{ id: "record-mic", group: "capture", name: "Record screen with microphone", desc: "Your voice mixed in", icon: "mic", keywords: "record screen microphone mic audio nagraj mikrofon", run: () => capture(bin + "record-screen --mic") },
		{ id: "record-cam", group: "capture", name: "Record screen with microphone and camera", desc: "Your voice and a camera overlay", icon: "webcam", keywords: "record screen microphone camera webcam kamera nagraj mikrofon", run: () => capture(bin + "record-screen --mic --cam") }
	], [
		{ id: "picker", group: "capture", name: "Color picker", desc: "Copies the hex value", icon: "pipette", keywords: "color colour picker pipette hex kolor pipeta", run: () => capture("hyprpicker -a --notify") },
		{ id: "ocr", group: "capture", name: "Copy text from screen", desc: "Recognises text in an area (OCR)", icon: "scan-text", keywords: "ocr text recognize scan tekst rozpoznaj", run: () => capture(bin + "ocr") },
		{ id: "dictation", group: "capture", name: "Dictation", desc: "Type by speaking", icon: "mic", tint: Theme.accentGreen, bind: "Dictation", keywords: "dictation voice speech whisper dyktowanie mowa głos", run: () => script("dictation") },

		{ id: "sysupdate", name: "System update", desc: "Upgrade the packages", icon: "package", keywords: "update sysupdate upgrade aktualizacja pacman paru system", run: () => terminal("sysupdate") },
		{ id: "sysclean", name: "System cleanup", desc: "Caches, orphaned packages, the trash", icon: "trash", keywords: "clean cleanup sysclean cache orphans trash czyszczenie sprzątanie kosz", run: () => terminal("sysclean") },

		{ id: "lock", name: "Lock", desc: "Lock the session", icon: "lock", bind: "Lock system", keywords: "lock zablokuj ekran lockscreen", run: () => spawn(["loginctl", "lock-session"]) },
		{ id: "suspend", name: "Suspend", desc: "Lock and sleep", icon: "moon", keywords: "suspend sleep uspij uśpij drzemka", run: () => spawn(["sh", "-c", "loginctl lock-session && systemctl suspend"]) },
		{ id: "logout", name: "Log out", desc: "Close every app and end the session", icon: "log-out", confirm: "log out", keywords: "logout log out relogin relog exit wyloguj przeloguj sesja", run: () => spawn(["hyprshutdown"]) },
		{ id: "reboot", name: "Reboot", desc: "Close every app and restart", icon: "rotate-cw", confirm: "reboot", keywords: "reboot restart uruchom ponownie zrestartuj", run: () => spawn(["hyprshutdown", "--post-cmd", "systemctl reboot"]) },
		{ id: "poweroff", name: "Power off", desc: "Close every app and shut down", icon: "power", confirm: "power off", keywords: "poweroff shutdown wylacz wyłącz power", run: () => spawn(["hyprshutdown", "--post-cmd", "systemctl poweroff"]) }
	])
}
