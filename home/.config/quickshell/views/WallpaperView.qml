import ".."
import Quickshell
import Quickshell.Wayland
import QtQuick

// Two stacked images per screen: a new wallpaper decodes in the hidden one,
// fades in over the old one, and the old one is dropped.
Variants {
	model: Quickshell.screens

	PanelWindow {
		id: win

		required property var modelData
		property Image front: first
		readonly property Image back: front === first ? second : first
		// What the screen shows or is about to show.
		property string target: ""

		screen: modelData
		color: Theme.bgMain
		WlrLayershell.layer: WlrLayer.Background
		WlrLayershell.namespace: "wallpaper"
		exclusionMode: ExclusionMode.Ignore

		anchors {
			top: true
			bottom: true
			left: true
			right: true
		}

		function show(): void {
			if (Wallpaper.url === "" || Wallpaper.url === target)
				return;
			if (fade.running) {
				fade.stop();
				settle();
			}
			target = Wallpaper.url;
			back.source = target;
		}

		function reveal(): void {
			// Nothing to fade from on the first load.
			if (front.status !== Image.Ready) {
				settle();
				return;
			}
			fade.target = back;
			fade.restart();
		}

		function settle(): void {
			var old = front;
			back.opacity = 1;
			front = back;
			old.opacity = 0;
			old.source = "";
		}

		Component.onCompleted: show()

		Connections {
			target: Wallpaper
			function onUrlChanged() {
				win.show();
			}
		}

		component Layer: Image {
			anchors.fill: parent
			z: win.front === this ? 0 : 1
			opacity: 0
			fillMode: Image.PreserveAspectCrop
			sourceSize: Wallpaper.decodeSize(win.modelData)
			asynchronous: true
			retainWhileLoading: true
			onStatusChanged: {
				if (status === Image.Ready && win.back === this)
					win.reveal();
			}
		}

		Layer {
			id: first
		}

		Layer {
			id: second
		}

		NumberAnimation {
			id: fade
			property: "opacity"
			from: 0
			to: 1
			duration: Theme.wallpaperFade
			easing.type: Easing.InOutSine
			onFinished: win.settle()
		}
	}
}
