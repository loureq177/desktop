import ".."
import QtQuick

// Text in the shell's type: the UI font at the body size in the main colour,
// unless told otherwise. `mono` for figures and what is typed.
Text {
	property bool mono: false

	// Hinted glyphs: Qt's own rendering is softer at these sizes.
	renderType: Text.NativeRendering

	font.family: mono ? Theme.fontMono : Theme.fontFamily
	font.pixelSize: Theme.fontSize
	color: Theme.textMain
}
