pragma Singleton
import Quickshell
import QtQuick

// What the desktop does, wherever the shell offers it: the launcher's
// search, the Capture page of Quick actions, the bar's modules. Each action of
// a list is { label, desc, lineIcon, keywords, bind, alert, tint, run }:
// `bind` is the description of the key bind that does the same, `alert` draws
// it in the critical colour.
Singleton {
	id: root

	readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

	// Without what the shell itself was started with (an EGL vendor, the
	// allocator's settings): what the shell starts picks its own. `env -C` sets the working directory:
	// execDetached takes no { command, workingDirectory } object (quickshell
	// 0.3.2 refuses it). The directory is untyped: a missing `string`
	// argument arrives as "undefined".
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

	function togglePowerSave(): void {
		script("power-save");
	}

	function toggleAwake(): void {
		script("awake-toggle");
	}

	// Screenshots, recordings and the other tools that take from the screen.
	readonly property var captureActions: [
		{ label: "Screenshot", desc: "An area or a window", lineIcon: "camera", bind: "Screenshot (region)", keywords: "screenshot capture region window zrzut ekranu", run: () => root.capture(root.bin + "screenshot region") },
		{ label: "Screenshot of the screen", desc: "The whole screen", lineIcon: "camera", bind: "Screenshot (full)", keywords: "screenshot full fullscreen capture zrzut cały ekran", run: () => root.capture(root.bin + "screenshot fullscreen") }
	].concat(SystemStatus.recording ? [
		{ label: "Stop recording", desc: "Save the screen recording", lineIcon: "circle-stop", alert: true, keywords: "record screen video recording stop nagrywanie zatrzymaj", run: () => root.script("record-screen") }
	] : [
		{ label: "Record screen", desc: "An area or a window", lineIcon: "video", keywords: "record screen video recording nagraj ekran wideo nagrywanie", run: () => root.capture(root.bin + "record-screen") },
		{ label: "Record screen with microphone", desc: "Your voice mixed in", lineIcon: "mic", keywords: "record screen microphone mic audio nagraj mikrofon", run: () => root.capture(root.bin + "record-screen --mic") },
		{ label: "Record screen with microphone and camera", desc: "Your voice and a camera overlay", lineIcon: "webcam", keywords: "record screen microphone camera webcam kamera nagraj mikrofon", run: () => root.capture(root.bin + "record-screen --mic --cam") }
	], [
		{ label: "Color picker", desc: "Copies the hex value", lineIcon: "pipette", keywords: "color colour picker pipette hex kolor pipeta", run: () => root.capture("hyprpicker -a --notify") },
		{ label: "Copy text from screen", desc: "Recognises text in an area (OCR)", lineIcon: "scan-text", keywords: "ocr text recognize scan tekst rozpoznaj", run: () => root.capture(root.bin + "ocr") },
		{ label: "Dictation", desc: "Type by speaking", lineIcon: "mic", tint: Theme.accentGreen, bind: "Dictation", keywords: "dictation voice speech whisper dyktowanie mowa głos", run: () => root.script("dictation") }
	])
}
