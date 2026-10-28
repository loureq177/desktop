import ".."
import QtQuick

// The highlight of the keyboard's (and the pointer's) place: one for a whole
// list or page, sliding from item to item in the time a list glides to it
// (WheelScroll.reveal), so the two move as one. Whoever declares it puts it
// over `item`; the first item is lit in place, not flown to.
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
