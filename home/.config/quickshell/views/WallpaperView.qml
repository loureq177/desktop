import ".."
import Quickshell
import Quickshell.Wayland
import QtQuick

// Two images per screen: the new wallpaper decodes hidden, then grows over the old
// one as a circle.
Variants {
	model: Quickshell.screens

	PanelWindow {
		id: win

		required property var modelData
		property Image front: first
		readonly property Image back: front === first ? second : first
		// What the screen shows or is about to show.
		property string target: ""
		// The circle the new wallpaper shows through while it grows.
		property point origin
		property real radius: 0

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
			if (grow.running) {
				grow.stop();
				settle();
			}
			target = Wallpaper.url;
			back.source = target;
		}

		function reveal(): void {
			// Nothing to grow over on the first load.
			if (front.status !== Image.Ready) {
				settle();
				return;
			}
			origin = Qt.point(Math.random() * width, Math.random() * height);
			// Far enough to pass the farthest corner, soft edge included.
			grow.to = Math.hypot(Math.max(origin.x, width - origin.x), Math.max(origin.y, height - origin.y)) + Theme.wallpaperFeather;
			grow.restart();
			back.opacity = 1;
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
			// Only the incoming image goes through the shader, and only while
			// it grows: a settled wallpaper is a plain image.
			layer.enabled: win.back === this && grow.running
			layer.effect: ShaderEffect {
				readonly property real radius: win.radius
				readonly property real feather: Theme.wallpaperFeather
				readonly property point center: win.origin
				readonly property size size: Qt.size(width, height)

				fragmentShader: Qt.resolvedUrl("../shaders/grow.frag.qsb")
			}
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

		// Darkens the top edge so the bar reads on a bright wallpaper; eased, so no line shows
		// where it ends.
		Rectangle {
			anchors {
				top: parent.top
				left: parent.left
				right: parent.right
			}
			height: 120
			z: 2
			gradient: Gradient {
				GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.34) }
				GradientStop { position: 0.25; color: Qt.rgba(0, 0, 0, 0.24) }
				GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.115) }
				GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, 0.035) }
				GradientStop { position: 1.0; color: "transparent" }
			}
		}

		NumberAnimation {
			id: grow
			target: win
			property: "radius"
			from: 0
			duration: Theme.wallpaperGrow
			easing.type: Easing.InOutSine
			onFinished: win.settle()
		}
	}
}
