import ".."
import QtQuick

// The key that does what a tile or button does, small in its corner, lit
// while that tile is selected (or the button under the pointer).
StyledText {
	property string key: ""
	property bool lit: false

	visible: key !== ""
	text: key
	mono: true
	font.pixelSize: 10
	font.bold: true
	color: lit ? Theme.textMain : Theme.textDim
	opacity: lit ? 0.9 : 0.6
}
