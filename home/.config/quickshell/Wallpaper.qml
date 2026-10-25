pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The wallpaper picked with ~/.local/bin/wallpaper, drawn by WallpaperView.
Singleton {
	id: root

	property string path: ""
	readonly property string url: path === "" ? "" : "file://" + path.split("/").map(encodeURIComponent).join("/")

	// Decoding at the screen's pixel size holds one screen's worth of pixels
	// however large the file is, and lets everything showing the wallpaper on
	// that screen share a single decode.
	function decodeSize(screen): size {
		// A surface has no screen for a moment while it is set up or torn down.
		if (!screen)
			return Qt.size(0, 0);
		return Qt.size(screen.width * screen.devicePixelRatio, screen.height * screen.devicePixelRatio);
	}

	FileView {
		path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/wallpaper/current"
		blockLoading: true
		printErrors: false
		watchChanges: true
		onFileChanged: reload()
		// The script truncates the file before writing it: an empty read is that gap.
		onLoaded: {
			var next = this.text().trim();
			if (next !== "")
				root.path = next;
		}
	}
}
