import ".."
import QtQuick

// The key that does what a tile or button does, small in its corner, lit
// while that tile is selected (or the button under the pointer).
Text {
	property string key: ""
	property bool lit: false

	visible: key !== ""
	text: key
	font.family: Theme.fontMono
	font.pixelSize: 10
	font.bold: true
	color: lit ? Theme.accentBlue : Theme.textDim
	opacity: lit ? 0.9 : 0.6
}
