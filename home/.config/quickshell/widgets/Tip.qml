import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// A tooltip in the shell's look, out of the card's clip, in the window's overlay.
ToolTip {
	id: tip

	delay: 500
	width: Math.min(implicitWidth, 420)
	padding: 8
	leftPadding: 10
	rightPadding: 10

	enter: Transition {
		NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animFast; easing.type: Easing.OutCubic }
		NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.animFast; easing.type: Easing.OutCubic }
	}
	exit: Transition {
		NumberAnimation { property: "opacity"; to: 0; duration: Theme.animFast; easing.type: Easing.OutCubic }
	}

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
		border.width: Theme.borderSize > 1 ? 1 : Theme.borderSize
		radius: Theme.roundingWindow
		layer.enabled: true
		layer.effect: MultiEffect {
			shadowEnabled: true
			shadowColor: "black"
			shadowOpacity: 0.5
			shadowBlur: 0.6
			shadowVerticalOffset: 2
		}
	}
}
