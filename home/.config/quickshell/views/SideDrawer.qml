import ".."
import "../widgets"
import QtQuick

SlideOverlay {
	id: root

	property int cardWidth: Theme.notifWidth
	property int cardHeight: Math.min(680, root.height - Theme.notifTopMargin - 20)

	signal drawerClosed()

	default property alias body: bodySlot.data

	// Well past the edge: the exit curve covers its last third in a frame or
	// two, so the card has to be gone before that or it visibly stops short.
	offscreenSlide: Math.round((root.cardWidth + Theme.notifRightMargin) * 1.6)

	onDismissRequested: root.dismissed()

	// Another drawer slides into the same spot: fade out in place underneath
	// it. The backdrop mirrors the newcomer's fade-in, so the dim stays level.
	handoffAnimation: ParallelAnimation {
		onRunningChanged: {
			if (!running) {
				card.opacity = 1.0;
				root.slide = root.offscreenSlide;
			}
		}

		NumberAnimation {
			target: card
			property: "opacity"
			to: 0.0
			duration: Theme.animFast
			easing.type: Easing.OutCubic
		}
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			from: root.backdropOpacity
			to: 0.0
			duration: Theme.animSmooth
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
	}
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

		x: parent.width - width - Theme.notifRightMargin + root.slide
		y: Theme.notifTopMargin
		width: root.cardWidth
		height: root.cardHeight
		color: Theme.panel(Theme.bgCard)
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
