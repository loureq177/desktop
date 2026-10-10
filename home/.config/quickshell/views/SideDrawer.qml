import ".."
import "../widgets"
import QtQuick

SlideOverlay {
	id: root

	property int cardWidth: Theme.notifWidth
	property int cardHeight: Math.min(680, root.height - Theme.notifTopMargin - 20)
	property bool fromLeft: false

	signal drawerClosed()

	default property alias body: bodySlot.data

	offscreenSlide: root.cardWidth + Theme.notifRightMargin

	onDismissRequested: root.dismissed()
	onFullyClosed: root.drawerClosed()

	Behavior on cardHeight {
		NumberAnimation {
			duration: Theme.animNormal
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
	}

	Rectangle {
		id: card

		x: root.fromLeft ? Theme.notifRightMargin - root.slide : parent.width - width - Theme.notifRightMargin + root.slide
		y: Theme.notifTopMargin
		width: root.cardWidth
		height: root.cardHeight
		color: Theme.bgCard
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingWindow
		clip: true

		Keys.onEscapePressed: event => {
			if (root.dismissOnEsc) {
				root.dismissed();
				event.accepted = true;
			}
		}

		MouseArea {
			anchors.fill: parent
			enabled: root.shown
			hoverEnabled: true
		}

		Item {
			id: bodySlot
			anchors.fill: parent
			anchors.margins: Theme.paddingCard
		}
	}
}
