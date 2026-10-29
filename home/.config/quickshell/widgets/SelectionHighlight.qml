import ".."
import QtQuick

// One highlight for a list, sliding in the time the list glides (WheelScroll.reveal);
// the first item is lit in place.
Rectangle {
	id: root

	property Item item: null
	// Off while there is no item to come from.
	property bool gliding: false

	onItemChanged: {
		if (!item)
			gliding = false;
		else if (!gliding)
			Qt.callLater(() => root.gliding = root.item !== null);
	}

	visible: item !== null
	radius: Theme.roundingElement
	color: Theme.selectionBg
	border.color: Theme.selectionBorder
	border.width: 1

	Behavior on x { enabled: root.gliding && root.visible; NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
	Behavior on y { enabled: root.gliding && root.visible; NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
	Behavior on width { enabled: root.gliding && root.visible; NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
	Behavior on height { enabled: root.gliding && root.visible; NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
}
