import ".."
import Quickshell
import QtQuick

// What the item under the pointer reads out (its `tooltipText`), below it,
// after a moment's rest there. Going on to the next item moves the tooltip
// that is up instead of waiting again.
PopupWindow {
	id: tip

	required property var host
	property Item target: null
	readonly property string text: target?.tooltipText ?? ""
	property bool open: false

	function enter(item: Item): void {
		hideTimer.stop();
		target = item;
		if (open)
			anchor.updateAnchor();
		else
			showTimer.restart();
	}

	function leave(item: Item): void {
		if (target !== item)
			return;
		showTimer.stop();
		hideTimer.restart();
	}

	function dismiss(): void {
		showTimer.stop();
		hideTimer.stop();
		open = false;
		target = null;
	}

	visible: open && text !== ""
	color: "transparent"
	implicitWidth: box.implicitWidth
	implicitHeight: box.implicitHeight
	onImplicitWidthChanged: anchor.updateAnchor()
	onVisibleChanged: anchor.updateAnchor()

	Timer {
		id: showTimer
		interval: 300
		onTriggered: tip.open = true
	}

	Timer {
		id: hideTimer
		interval: 100
		onTriggered: tip.dismiss()
	}

	anchor {
		window: tip.host
		adjustment: PopupAdjustment.SlideX
		gravity: Edges.Bottom | Edges.Right

		onAnchoring: {
			var item = tip.target;
			if (!item)
				return;
			var pos = tip.host.contentItem.mapFromItem(item, Math.round(item.width / 2 - tip.width / 2), item.height + 6);
			tip.anchor.rect.x = Math.max(0, Math.min(tip.host.width - tip.width, pos.x));
			tip.anchor.rect.y = pos.y;
		}
	}

	Rectangle {
		id: box
		implicitWidth: label.implicitWidth + 20
		implicitHeight: label.implicitHeight + 10
		color: Theme.bgCard
		border.color: Theme.border
		border.width: 1
		radius: Theme.roundingElement

		StyledText {
			id: label
			anchors.centerIn: parent
			text: tip.text
			font.pixelSize: Theme.fontSizeSmall
		}
	}
}
