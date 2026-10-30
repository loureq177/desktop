import ".."
import QtQuick
import QtQuick.Controls

// A tooltip in the shell's look, out of the card's clip, in the window's overlay.
ToolTip {
	id: tip

	delay: 500
	width: Math.min(implicitWidth, 420)
	padding: 8
	leftPadding: 10
	rightPadding: 10

	contentItem: StyledText {
		text: tip.text
		textFormat: Text.PlainText
		wrapMode: Text.Wrap
		lineHeight: 1.15
		font.pixelSize: Theme.fontSizeSmall
		color: Theme.textMain
	}

	background: Rectangle {
		color: Theme.bgCard
		border.color: Theme.border
		border.width: 1
		radius: Theme.roundingElement
	}
}
