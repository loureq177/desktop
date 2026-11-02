import ".."
import Quickshell
import QtQuick

// Tip's look under a bar module, in its own window: the bar's is only as tall as the strip.
PopupWindow {
	id: tip

	required property Item target
	property bool shown: false
	property string text: ""
	property bool up: false

	anchor.item: target
	anchor.rect.x: 0
	anchor.rect.y: target.height + 6
	anchor.rect.width: target.width
	anchor.rect.height: 1
	anchor.edges: Edges.Top
	anchor.gravity: Edges.Bottom
	color: "transparent"
	implicitWidth: card.width
	implicitHeight: card.height
	// Nothing to click: the pointer goes through.
	mask: Region {}
	visible: up || card.opacity > 0

	onShownChanged: {
		if (shown) {
			delay.restart();
		} else {
			delay.stop();
			up = false;
		}
	}

	Timer {
		id: delay
		interval: 500
		onTriggered: tip.up = true
	}

	Rectangle {
		id: card
		width: label.implicitWidth + 20
		height: label.implicitHeight + 16
		color: Theme.bgCard
		border.color: Theme.border
		border.width: Theme.borderSize > 1 ? 1 : Theme.borderSize
		radius: Theme.roundingWindow
		opacity: tip.up ? 1 : 0

		Behavior on opacity {
			NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
		}

		StyledText {
			id: label
			anchors.centerIn: parent
			text: tip.text
			font.pixelSize: Theme.fontSizeSmall
		}
	}
}
