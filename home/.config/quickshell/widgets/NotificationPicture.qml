// Shared notification picture: shows the notification image (avatars etc.)
// left of the text, falling back to the app icon. Notification.image is
// always directly loadable by Image: quickshell converts image-data hints to
// an image:// URL and image-path hints to a file path or image://icon URL.
import ".."
import Quickshell
import QtQuick

Item {
	id: root

	required property string image
	required property string appIcon
	property int size: 40

	// image wins; appIcon covers apps that only set an icon. appIcon may be
	// a bare icon name (resolve through the theme) or a path/URL (verbatim).
	readonly property bool hasImage: root.image !== ""
	readonly property string iconSource: {
		if (root.hasImage)
			return "";
		var icon = root.appIcon || "";
		if (icon === "")
			return "";
		if (icon.startsWith("/") || icon.startsWith("file:") || icon.startsWith("image:"))
			return icon;
		return Quickshell.iconPath(icon, "");
	}

	visible: root.hasImage || root.iconSource !== ""
	implicitWidth: root.size
	implicitHeight: root.size

	// Cap the decoded size at 2x the display box: an image hint is attacker
	// controlled, and without sourceSize Qt decodes it at full resolution.
	Image {
		anchors.fill: parent
		visible: root.hasImage
		source: root.image
		fillMode: Image.PreserveAspectFit
		asynchronous: true
		cache: false
		sourceSize.width: root.size * 2
		sourceSize.height: root.size * 2
	}
	Image {
		anchors.fill: parent
		visible: !root.hasImage && root.iconSource !== ""
		source: root.iconSource
		fillMode: Image.PreserveAspectFit
		asynchronous: true
		sourceSize.width: root.size * 2
		sourceSize.height: root.size * 2
	}
}
