import ".."
import Quickshell.Widgets
import QtQuick

// The notification's picture (an avatar, a screenshot); app icons and placeholders are
// left out.
Item {
	id: root

	required property string image
	required property string appIcon
	property int size: 64

	// The image hint, else an icon that is really a picture: `notify-send -i
	// file` (the screenshot script) passes its file as the app icon.
	readonly property string source: root.pictureUrl(root.image) || root.pictureUrl(root.appIcon)
	// While it loads too: waiting for Ready would jump the layout.
	readonly property bool hasPicture: root.source !== "" && img.status !== Image.Error
	// Width over height once it has loaded: a screenshot is shown whole, under the text.
	readonly property real aspect: img.status === Image.Ready && img.sourceSize.height > 0 ? img.sourceSize.width / img.sourceSize.height : 1

	implicitWidth: root.hasPicture ? root.size : 0
	implicitHeight: root.hasPicture ? root.size : 0
	visible: root.hasPicture

	// The URL of a picture, or "" for an icon: one by name, or a file from an
	// icon theme.
	function pictureUrl(raw: string): string {
		var pic = (raw || "").trim();
		if (pic.startsWith("data:") || pic.startsWith("http:") || pic.startsWith("https:"))
			return pic;
		// Pixels sent with the notification itself (image-data), e.g. avatars.
		if (pic.startsWith("image://qsimage/"))
			return pic;
		if (pic.startsWith("image://icon//"))
			pic = pic.slice("image://icon/".length);
		else if (pic.startsWith("image://icon/file://"))
			pic = pic.slice("image://icon/".length);
		if (!pic.startsWith("/") && !pic.startsWith("file:"))
			return "";
		if (pic.includes("/icons/") || pic.includes("/pixmaps/") || pic.endsWith(".svg"))
			return "";
		return pic.startsWith("/") ? "file://" + pic : pic;
	}

	// Bare, no tile behind it: a site's icon (Firefox sends those as pixels)
	// is see-through around the edges, and a tile there framed it in black.
	// A square one is cut round: avatars come as a circle on a white square (WhatsApp).
	ClippingRectangle {
		anchors.fill: parent
		radius: Math.abs(root.aspect - 1) < 0.15 ? width / 2 : Theme.roundingElement
		color: "transparent"

		Image {
			id: img
			anchors.fill: parent
			source: root.source
			fillMode: Image.PreserveAspectCrop
			asynchronous: true
			cache: false
			mipmap: true
		}
	}
}
