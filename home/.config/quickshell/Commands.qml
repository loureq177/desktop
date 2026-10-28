pragma Singleton
import Quickshell
import QtQuick

// What the desktop does, wherever the shell offers it: the launcher finds a
// command by name, the bar and the tiles of Actions run it by id. Each is
// { id, name, desc, icon, keywords, run } and maybe
//   active   a switch's state: the launcher offers to turn it off
//   confirm  the verb of what runs on a second Enter only ("reboot")
//   alert    drawn in the critical colour; tint: its icon's colour
//   group    its section of the launcher's "/" list
// `run` returning false keeps the launcher open (it opened another panel).
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

	// What picks from the screen starts once the panel that asked has slid
	// away, so that it is not in the picture.
	function capture(commandLine: string): void {
		Panels.close();
		Hypr.exec(["sh", "-c", "sleep " + (Theme.animNormal + 50) / 1000 + " && " + commandLine]);
	}

	// hyprshutdown closes every app, then ends Hyprland and runs `then`. A
	// machine that adds a mesa-egl script (not this repo's) keeps it on the
	// iGPU's EGL: NVIDIA's would wake the sleeping dGPU and hold its screen
	// back 1.75 s.
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

	readonly property var all: [
		{ id: "wifi", group: "connections", name: "Wi-Fi", desc: "Networks", icon: "wifi", keywords: "wifi wi-fi network wireless internet sieć", run: () => open("actions", "wifi") },
		{ id: "bluetooth", group: "connections", name: "Bluetooth", desc: "Devices", icon: "bluetooth", keywords: "bluetooth headphones devices słuchawki urządzenia", run: () => open("actions", "bluetooth") },
		{ id: "dnd", group: "modes", name: "Do not disturb", desc: "Silence notifications", icon: "bell-off", active: Notifications.dnd, tint: Theme.warning, keywords: "dnd do not disturb quiet silence nie przeszkadzać cisza", run: () => { Notifications.dnd = !Notifications.dnd; } },
		{ id: "powersave", group: "modes", name: "Battery saver", desc: "60 Hz, dimmer, fewer effects", icon: "leaf", active: Modes.powerSave, tint: Theme.accentGreen, keywords: "battery saver power save 60hz oszczędzanie bateria", run: () => script("power-save") },
		...(Modes.batteryCareSupported ? [
			{ id: "batterycare", group: "modes", name: "Battery care", desc: "Stops charging short of full", icon: "battery-medium", active: Modes.batteryCare, tint: Theme.accentGreen, keywords: "battery care health charge limit long life conservation zdrowie baterii limit ładowania ochrona", run: () => script("battery-care") }
		] : []),
		{ id: "nightlight", group: "modes", name: "Night light", desc: "turns on at 8 PM", icon: "moon", active: Modes.nightLight, tint: Theme.warning, keywords: "night light blue light filter warm hyprsunset tryb nocny ciepłe kolory", run: () => Modes.toggleNightLight() },
		{ id: "awake", group: "modes", name: "Keep awake", desc: "The screen stays on", icon: "coffee", active: Modes.awake, keywords: "keep awake caffeine inhibit idle sleep nie usypiaj", run: () => script("awake-toggle") },

	].concat(Modes.recording ? [
		{ id: "record", group: "capture", name: "Stop recording", desc: "Save the screen recording", icon: "circle-stop", alert: true, keywords: "record screen video recording stop nagrywanie zatrzymaj", run: () => script("record-screen") }
	] : [
		{ id: "record", group: "capture", name: "Record screen", desc: "An area or a window", icon: "video", keywords: "record screen video recording nagraj ekran wideo nagrywanie", run: () => capture(bin + "record-screen") },
		{ id: "record-mic", group: "capture", name: "Record screen with microphone", desc: "Your voice mixed in", icon: "mic", keywords: "record screen microphone mic audio nagraj mikrofon", run: () => capture(bin + "record-screen --mic") },
		{ id: "record-cam", group: "capture", name: "Record screen with microphone and camera", desc: "Your voice and a camera overlay", icon: "webcam", keywords: "record screen microphone camera webcam kamera nagraj mikrofon", run: () => capture(bin + "record-screen --mic --cam") }
	], [
		{ id: "picker", group: "capture", name: "Color picker", desc: "Copies the hex value", icon: "pipette", keywords: "color colour picker pipette hex kolor pipeta", run: () => capture("hyprpicker -a --notify") },
		{ id: "ocr", group: "capture", name: "OCR", desc: "Copy text from screen", icon: "scan-text", keywords: "ocr text recognize scan tekst rozpoznaj", run: () => capture(bin + "ocr") },

		{ id: "sysupdate", group: "system", name: "System update", desc: "Upgrade the packages", icon: "package", keywords: "update sysupdate upgrade aktualizacja pacman paru system", run: () => terminal("sysupdate") },
		{ id: "sysclean", group: "system", name: "System cleanup", desc: "Caches, orphaned packages, the trash", icon: "trash", keywords: "clean cleanup sysclean cache orphans trash czyszczenie sprzątanie kosz", run: () => terminal("sysclean") },

		{ id: "suspend", group: "session", name: "Suspend", desc: "Lock and sleep", icon: "moon", keywords: "suspend sleep uspij uśpij drzemka", run: () => Hypr.exec(["sh", "-c", "loginctl lock-session && systemctl suspend"]) },
		{ id: "logout", group: "session", name: "Log out", desc: "Close the apps, end the session", icon: "log-out", confirm: "log out", keywords: "logout log out relogin relog exit wyloguj przeloguj sesja", run: () => shutdown("") },
		{ id: "reboot", group: "session", name: "Reboot", desc: "Close the apps, restart", icon: "rotate-cw", confirm: "reboot", keywords: "reboot restart uruchom ponownie zrestartuj", run: () => shutdown("systemctl reboot --no-wall") },
		{ id: "poweroff", group: "session", name: "Power off", desc: "Close the apps, shut down", icon: "power", confirm: "power off", keywords: "poweroff shutdown wylacz wyłącz power", run: () => shutdown("systemctl poweroff --no-wall") }
	])
}
