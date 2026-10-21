import ".."
import "../widgets"
import QtQuick

// The card under the bar's right end that Actions and the notification
// center take turns in.
OverlayWindow {
	id: root

	property int cardWidth: Theme.notifWidth
	property int cardHeight: Math.min(680, root.height - Theme.notifTopMargin - 20)

	default property alias body: bodySlot.data

	style: "slide"
	card: drawerCard
	handoff: Panels.active === "actions" || Panels.active === "notifications"
	// Well past the edge: the exit curve covers its last third in a frame or
	// two, so the card has to be gone before that or it visibly stops short.
	offscreenSlide: Math.round((root.cardWidth + Theme.notifRightMargin) * 1.6)

	onDismissRequested: Panels.close(root.panel)

	Behavior on cardHeight {
		NumberAnimation {
			duration: Theme.animNormal
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
	}

	Rectangle {
		id: drawerCard

		x: parent.width - width - Theme.notifRightMargin + root.slide
		y: Theme.notifTopMargin
		width: root.cardWidth
		height: root.cardHeight
		color: Theme.glass(Theme.bgCard)
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingWindow
		clip: true

		Keys.onEscapePressed: event => {
			if (root.dismissOnEsc) {
				root.dismissRequested();
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
