import "../.."
import "."
import Quickshell
import QtQuick

ActionListSubView {
	id: root

	title: "Capture"

	// The panel is gone by the time the area picker comes up.
	readonly property string recordCmd: "sleep 0.15 && ~/.local/bin/record-screen"
	readonly property var recordActions: SystemStatus.recording ? [
		{
			title: "Stop Recording",
			desc: "Save the screen recording",
			icon: "circle-stop",
			alert: true,
			cmd: "~/.local/bin/record-screen"
		}
	] : [
		{
			title: "Screen Record",
			desc: "Record an area or a window",
			icon: "video",
			cmd: recordCmd
		},
		{
			title: "Screen Record + Microphone",
			desc: "With the microphone mixed in",
			icon: "mic",
			cmd: recordCmd + " --mic"
		},
		{
			title: "Screen Record + Microphone + Camera",
			desc: "With the microphone and a camera overlay",
			icon: "webcam",
			cmd: recordCmd + " --mic --cam"
		}
	]

	actions: [
		{
			title: "Screenshot",
			desc: "Interactive window or region capture",
			icon: "camera",
			cmd: "sleep 0.15 && ~/.local/bin/screenshot region"
		}
	].concat(recordActions, [
		{
			title: "Color Picker",
			desc: "Pick screen color & copy HEX to clipboard",
			icon: "pipette",
			cmd: "sleep 0.15 && hyprpicker -a --notify"
		},
		{
			title: "Text OCR",
			desc: "Select area & copy extracted text to clipboard",
			icon: "scan-text",
			cmd: "sleep 0.15 && ~/.local/bin/ocr"
		},
		{
			title: "Voice Dictation",
			desc: "Transcribe voice into focused application",
			icon: "mic",
			tint: Theme.accentGreen,
			cmd: "~/.local/bin/dictation"
		}
	]).map(a => Object.assign({ run: () => root.runCommand(a.cmd) }, a))

	function runCommand(cmd) {
		Panels.closeInstant();
		Quickshell.execDetached(["sh", "-c", cmd]);
	}
}
