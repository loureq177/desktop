// Shared notification picture: shows the notification image (avatars etc.)
// left of the text, falling back to app icons or a clean stylized badge.
// Handles Quickshell image://icon URL quirks and file paths cleanly without
// ever displaying raw texture glitches or broken image placeholders.
import ".."
import Quickshell
import QtQuick

Item {
	id: root

	required property string image
	required property string appIcon
	property string appName: ""
	property int size: 64

	// Clean up image source:
	// Quickshell's notification server sometimes prepends "image://icon/" to
	// absolute paths like "/tmp/.../icon.png". Normalize those to file:// URLs.
	readonly property string resolvedImage: {
		var img = root.image || "";
		if (img === "")
			return "";
		if (img.startsWith("image://icon//"))
			return "file:///" + img.slice(14);
		if (img.startsWith("image://icon/file://"))
			return img.slice(13);
		if (img.startsWith("/") || img.startsWith("file:") || img.startsWith("image:"))
			return img;
		return img;
	}

	readonly property string resolvedIcon: {
		var icon = root.appIcon || "";
		if (icon === "" && root.appName !== "")
			icon = root.appName.toLowerCase().replace(/[^a-z0-9_-]/g, "");
		if (icon === "")
			return "";
		if (icon.startsWith("/") || icon.startsWith("file:") || icon.startsWith("image:"))
			return icon;
		if (Quickshell.hasThemeIcon(icon))
			return Quickshell.iconPath(icon);
		return "";
	}

	// Determine fallback icon glyph based on appName
	readonly property string fallbackGlyph: {
		var name = (root.appName || "").toLowerCase();
		if (name.includes("chrom"))
			return "󰊯";
		if (name.includes("firef"))
			return "󰈹";
		if (name.includes("spot"))
			return "󰓇";
		if (name.includes("disc"))
			return "󰙯";
		if (name.includes("term") || name.includes("ghost") || name.includes("alacritty") || name.includes("kitty"))
			return "󰊴";
		if (name.includes("mail") || name.includes("gmail") || name.includes("thunder"))
			return "󰇮";
		if (name.includes("cal"))
			return "󰃭";
		if (name.includes("code") || name.includes("nvim") || name.includes("vim"))
			return "󰨞";
		return "󰂚";
	}

	implicitWidth: root.size
	implicitHeight: root.size

	// Main notification image (album art, screenshots, avatars) - clipped with theme rounding
	Rectangle {
		id: imgContainer
		anchors.fill: parent
		visible: root.resolvedImage !== "" && mainImg.status === Image.Ready && !mainImg.failed
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
			sourceSize.width: Math.max(1, parent.width * 2)
			sourceSize.height: Math.max(1, parent.height * 2)
			property bool failed: false
			onStatusChanged: {
				if (status === Image.Error)
					failed = true;
			}
		}
	}

	// App icon: clean, unboxed, preserves icon theme fidelity without nested borders
	Image {
		id: iconImg
		anchors.fill: parent
		visible: !imgContainer.visible && root.resolvedIcon !== "" && status === Image.Ready && !failed
		source: root.resolvedIcon
		fillMode: Image.PreserveAspectFit
		asynchronous: true
		sourceSize.width: Math.max(1, parent.width * 2)
		sourceSize.height: Math.max(1, parent.height * 2)
		property bool failed: false
		onStatusChanged: {
			if (status === Image.Error)
				failed = true;
		}
	}

	// Fallback glyph badge for notifications without image or app icon
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
