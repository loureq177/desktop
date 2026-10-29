pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The wallpaper picked with ~/.local/bin/wallpaper, drawn by WallpaperView.
Singleton {
	id: root

	property string path: ""
	readonly property string url: path === "" ? "" : "file://" + path.split("/").map(encodeURIComponent).join("/")

	// Decoded at the screen's size: one screen of pixels whatever the file, shared by all
	// that show it.
	function decodeSize(screen): size {
		// A surface has no screen for a moment while it is set up or torn down.
		if (!screen)
			return Qt.size(0, 0);
		return Qt.size(screen.width * screen.devicePixelRatio, screen.height * screen.devicePixelRatio);
	}

	// Another one than the one before (SUPER + P), not the first read.
	signal switched()

	FileView {
		path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/wallpaper/current"
		blockLoading: true
		printErrors: false
		watchChanges: true
		onFileChanged: reload()
		// The script truncates the file before writing it: an empty read is that gap.
		onLoaded: {
			var next = this.text().trim();
			if (next === "" || next === root.path)
				return;
			var first = root.path === "";
			root.path = next;
			if (!first)
				root.switched();
		}
	}
}
