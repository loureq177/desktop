import ".."
import Quickshell.Wayland
import QtQuick

OverlayWindow {
	id: root

	property int offscreenSlide: 0
	property int slide: offscreenSlide

	layer: WlrLayer.Top
	keyboardFocusMode: WlrKeyboardFocus.OnDemand
	grabFocus: true

	onOffscreenSlideChanged: {
		if (!shown && !animating)
			slide = offscreenSlide;
	}

	onSnapped: root.slide = root.offscreenSlide

	enterAnimation: ParallelAnimation {
		NumberAnimation {
			target: root
			property: "slide"
			from: root.slide
			to: 0
			duration: Theme.animSmooth
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			from: root.backdropOpacity
			to: 1.0
			duration: Theme.animSmooth
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
	}

	exitAnimation: ParallelAnimation {
		NumberAnimation {
			target: root
			property: "slide"
			from: root.slide
			to: root.offscreenSlide
			duration: Theme.animNormal
			easing.type: Easing.InCubic
		}
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			from: root.backdropOpacity
			to: 0.0
			duration: Theme.animNormal
			easing.type: Easing.InCubic
		}
	}
}
