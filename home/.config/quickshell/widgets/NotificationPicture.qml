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

	// Resolved image source: ONLY for real photos/screenshots/avatars.
	// System icons and SVG files are intentionally excluded here so they render
	// as clean, unboxed vector icons rather than enclosed cards.
	readonly property string resolvedImage: {
		var img = (root.image || "").trim();
		if (img === "")
			return "";
		var path = "";
		if (img.startsWith("image://icon//"))
			path = "/" + img.slice(14);
		else if (img.startsWith("image://icon/file://"))
			path = img.slice(13);
		else if (img.startsWith("/") || img.startsWith("file:"))
			path = img;
		else if (img.startsWith("data:") || img.startsWith("http:") || img.startsWith("https:"))
			return img;

		if (path === "")
			return "";

		// If the file path points to an icon directory or is an SVG icon,
		// treat it as an app icon (unboxed, transparent), not a photo card!
		if (path.includes("/icons/") || path.includes("/pixmaps/") || path.endsWith(".svg"))
			return "";

		return path.startsWith("/") ? ("file://" + path) : path;
	}

	// Identify the icon candidate name from appIcon, image, or appName
	readonly property string iconCandidate: {
		var icon = (root.appIcon || "").trim();
		if (icon === "" && root.image) {
			var img = root.image.trim();
			if (img.startsWith("image://icon/") && !img.startsWith("image://icon//") && !img.startsWith("image://icon/file://"))
				icon = img.slice(13);
			else if (img.startsWith("image://icon//"))
				icon = "/" + img.slice(14);
			else if (img.startsWith("image://icon/file://"))
				icon = img.slice(13);
			else if (img.includes("/icons/") || img.includes("/pixmaps/") || img.endsWith(".svg"))
				icon = img;
			else if (!img.startsWith("/") && !img.startsWith("file:") && !img.startsWith("data:") && !img.startsWith("http:") && !img.startsWith("https:"))
				icon = img;
		}
		if (icon === "" && root.appName) {
			var entry = DesktopEntries.heuristicLookup(root.appName);
			if (entry && entry.icon)
				icon = entry.icon;
			else
				icon = root.appName.toLowerCase().replace(/[^a-z0-9_-]/g, "");
		}
		return icon;
	}

	// Generate ordered candidate file paths for the icon candidate
	function getCandidatePaths(rawIcon): var {
		if (!rawIcon)
			return [];
		var n = rawIcon.trim();
		if (n.startsWith("image://icon/"))
			n = n.slice(13);
		if (n.startsWith("/") || n.startsWith("file:"))
			return [n.startsWith("/") ? ("file://" + n) : n];

		var base = n.toLowerCase();

		// Standalone Arch Linux logo (pure "A" shape, no enclosing circle)
		if (base === "archlinux" || base === "arch" || base === "archlinux-logo" || base === "arch-logo") {
			return [
				"file:///usr/share/pixmaps/archlinux-logo.svg",
				"file:///usr/share/pixmaps/archlinux-logo.png",
				"file:///usr/share/icons/Papirus/64x64/apps/distributor-logo-archlinux.svg"
			];
		}

		var aliases = [base];

		// Common icon aliases
		if (base === "software-update-available" || base === "software-update-urgent" || base === "update-manager" || base === "system-update" || base === "system-software-update") {
			return [
				"file:///usr/share/pixmaps/archlinux-logo.svg",
				"file:///usr/share/icons/Papirus/64x64/apps/distributor-logo-archlinux.svg",
				"file:///usr/share/icons/Papirus/64x64/apps/system-software-update.svg"
			];
		} else if (base === "info") {
			aliases = ["dialog-information", "info"];
		} else if (base === "warning") {
			aliases = ["dialog-warning", "warning"];
		} else if (base === "error") {
			aliases = ["dialog-error", "error"];
		} else if (base === "system-reboot" || base === "reboot") {
			aliases = ["system-reboot", "view-refresh"];
		}

		var candidates = [];
		for (var i = 0; i < aliases.length; i++) {
			var a = aliases[i];
			if (a.startsWith("dialog-") || a.startsWith("weather-") || a.startsWith("battery-") || a.startsWith("network-")) {
				candidates.push("file:///usr/share/icons/Papirus/48x48/status/" + a + ".svg");
				candidates.push("file:///usr/share/icons/Papirus/24x24/panel/" + a + ".svg");
				candidates.push("file:///usr/share/icons/Papirus/22x22/panel/" + a + ".svg");
				candidates.push("file:///usr/share/icons/Papirus/64x64/status/" + a + ".svg");
			} else if (a.startsWith("camera-") || a.startsWith("video-") || a.startsWith("audio-") || a.startsWith("input-") || a.startsWith("drive-")) {
				candidates.push("file:///usr/share/icons/Papirus/64x64/devices/" + a + ".svg");
				candidates.push("file:///usr/share/icons/Papirus/48x48/devices/" + a + ".svg");
			}
			candidates.push("file:///usr/share/icons/Papirus/64x64/apps/" + a + ".svg");
			candidates.push("file:///usr/share/icons/Papirus/48x48/status/" + a + ".svg");
			candidates.push("file:///usr/share/icons/Papirus/64x64/categories/" + a + ".svg");
			candidates.push("file:///usr/share/icons/Papirus/64x64/devices/" + a + ".svg");
			candidates.push("file:///usr/share/icons/Papirus/24x24/panel/" + a + ".svg");
			candidates.push("file:///usr/share/icons/hicolor/scalable/apps/" + a + ".svg");
			candidates.push("file:///usr/share/pixmaps/" + a + ".svg");
			candidates.push("file:///usr/share/pixmaps/" + a + ".png");
		}
		return candidates;
	}

	// Determine fallback icon glyph based on appName and icon candidate
	readonly property string fallbackGlyph: {
		var name = (root.appName || "").toLowerCase();
		var ic = (root.iconCandidate || "").toLowerCase();
		var combo = name + " " + ic;

		if (combo.includes("arch"))
			return "󰣇";
		if (combo.includes("update") || combo.includes("upgrade") || combo.includes("pacman") || combo.includes("paru"))
			return "󰣇";
		if (combo.includes("reboot") || combo.includes("restart"))
			return "󰜉";
		if (combo.includes("warn") || combo.includes("alert"))
			return "󰀪";
		if (combo.includes("error") || combo.includes("fail"))
			return "󰅚";
		if (combo.includes("screen") || combo.includes("shot") || combo.includes("record") || combo.includes("camera"))
			return "󰄀";
		if (combo.includes("weather") || combo.includes("bedtime") || combo.includes("night"))
			return "󰖔";
		if (combo.includes("rclone") || combo.includes("sync") || combo.includes("cloud"))
			return "󰁪";
		if (combo.includes("ocr"))
			return "󰚢";
		if (combo.includes("chrom"))
			return "󰊯";
		if (combo.includes("firef"))
			return "󰈹";
		if (combo.includes("spot"))
			return "󰓇";
		if (combo.includes("disc"))
			return "󰙯";
		if (combo.includes("term") || combo.includes("ghost") || combo.includes("alacritty") || combo.includes("kitty"))
			return "󰊴";
		if (combo.includes("mail") || combo.includes("gmail") || combo.includes("thunder"))
			return "󰇮";
		if (combo.includes("cal"))
			return "󰃭";
		if (combo.includes("code") || combo.includes("nvim") || combo.includes("vim"))
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
				if (status === Image.Ready && (sourceSize.width <= 2 && sourceSize.height <= 2))
					failed = true;
			}
		}
	}

	// App icon: clean, unboxed, preserves icon theme fidelity without nested borders.
	// Tries candidate paths sequentially if earlier candidates fail, falling back
	// gracefully without ever rendering broken checkerboard textures.
	Image {
		id: iconImg
		anchors.fill: parent
		visible: !imgContainer.visible && status === Image.Ready && !failed
		fillMode: Image.PreserveAspectFit
		asynchronous: true
		sourceSize.width: Math.max(1, parent.width * 2)
		sourceSize.height: Math.max(1, parent.height * 2)

		property var candidates: root.getCandidatePaths(root.iconCandidate)
		property int candidateIndex: 0
		property bool failed: false

		source: candidates && candidates.length > 0 ? candidates[0] : ""

		onCandidatesChanged: {
			candidateIndex = 0;
			failed = false;
			source = candidates && candidates.length > 0 ? candidates[0] : "";
		}

		onStatusChanged: {
			if (status === Image.Error) {
				candidateIndex++;
				if (candidates && candidateIndex < candidates.length) {
					source = candidates[candidateIndex];
				} else {
					failed = true;
				}
			} else if (status === Image.Ready) {
				if (sourceSize.width <= 2 && sourceSize.height <= 2)
					failed = true;
			}
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
