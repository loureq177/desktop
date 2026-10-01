// Shared notification picture: displays avatars/photos, app vector icons,
// or a stylized fallback badge. Leverages Quickshell's iconPath resolution
// without requiring hardcoded filesystem paths.
import ".."
import Quickshell
import Quickshell.Widgets
import QtQuick

Item {
	id: root

	required property string image
	required property string appIcon
	property string appName: ""
	property int size: 64

	implicitWidth: root.size
	implicitHeight: root.size

	// Check if image is a real photo/screenshot/avatar rather than an icon file
	readonly property string resolvedImage: {
		var img = (root.image || "").trim();
		if (img === "")
			return "";
		if (img.startsWith("data:") || img.startsWith("http:") || img.startsWith("https:"))
			return img;
		if (img.startsWith("image://icon//"))
			return "file:///" + img.slice(14);
		if (img.startsWith("image://icon/file://"))
			return img.slice(13);
		if (img.startsWith("/") || img.startsWith("file:")) {
			if (img.includes("/icons/") || img.includes("/pixmaps/") || img.endsWith(".svg"))
				return ""; // icon, not photo
			return img.startsWith("/") ? ("file://" + img) : img;
		}
		return "";
	}

	readonly property string iconCandidate: {
		var ic = (root.appIcon || "").trim();
		if (ic === "" && root.image) {
			var img = root.image.trim();
			if (img.startsWith("image://icon/") && !img.startsWith("image://icon//") && !img.startsWith("image://icon/file://"))
				ic = img.slice(13);
			else if (img.includes("/icons/") || img.includes("/pixmaps/") || img.endsWith(".svg"))
				ic = img;
			else if (!img.startsWith("/") && !img.startsWith("file:") && !img.startsWith("data:") && !img.startsWith("http:"))
				ic = img;
		}
		if (ic === "" && root.appName) {
			var entry = DesktopEntries.heuristicLookup(root.appName);
			ic = (entry && entry.icon) ? entry.icon : root.appName.toLowerCase().replace(/[^a-z0-9_-]/g, "");
		}
		return ic;
	}

	readonly property string resolvedIconPath: {
		if (!iconCandidate || resolvedImage !== "")
			return "";
		if (iconCandidate.startsWith("/") || iconCandidate.startsWith("file:"))
			return iconCandidate.startsWith("/") ? ("file://" + iconCandidate) : iconCandidate;
		return Quickshell.iconPath(iconCandidate, true) || "";
	}

	readonly property string fallbackGlyph: {
		var combo = ((root.appName || "") + " " + root.iconCandidate).toLowerCase();
		if (combo.includes("arch") || combo.includes("pacman") || combo.includes("paru") || combo.includes("update"))
			return "󰣇";
		if (combo.includes("reboot") || combo.includes("restart"))
			return "󰜉";
		if (combo.includes("warn") || combo.includes("alert"))
			return "󰀪";
		if (combo.includes("error") || combo.includes("fail"))
			return "󰅚";
		if (combo.includes("audio") || combo.includes("music") || combo.includes("spotify") || combo.includes("player"))
			return "󰝚";
		if (combo.includes("chat") || combo.includes("message") || combo.includes("discord") || combo.includes("telegram"))
			return "󰭹";
		if (combo.includes("mail"))
			return "󰇮";
		if (combo.includes("cal"))
			return "󰃭";
		if (combo.includes("code") || combo.includes("nvim") || combo.includes("vim"))
			return "󰨞";
		return "󰂚";
	}

	// 1. Photo/screenshot image (clipped with theme rounding)
	Rectangle {
		id: imgContainer
		anchors.fill: parent
		visible: root.resolvedImage !== "" && mainImg.status === Image.Ready
		radius: Theme.roundingElement
		color: Theme.bgCard
		border.color: Theme.border
		border.width: 1
		clip: true

		Image {
			id: mainImg
			anchors.fill: parent
			source: root.resolvedImage
			fillMode: Image.PreserveAspectCrop
			asynchronous: true
			cache: false
		}
	}

	// 2. Vector app icon via Quickshell IconImage (preserves icon theme without extra border)
	IconImage {
		id: iconImg
		anchors.fill: parent
		visible: !imgContainer.visible && root.resolvedIconPath !== ""
		source: root.resolvedIconPath
		asynchronous: true
	}

	// 3. Fallback glyph badge
	Rectangle {
		anchors.fill: parent
		visible: !imgContainer.visible && !iconImg.visible
		radius: Theme.roundingElement
		color: Theme.bgHover
		border.color: Theme.border
		border.width: 1

		Text {
			anchors.centerIn: parent
			text: root.fallbackGlyph
			font.family: Theme.fontFamily
			font.pixelSize: Math.round(Math.min(parent.width, parent.height) * 0.48)
			color: Theme.accentBlue
		}
	}
}
