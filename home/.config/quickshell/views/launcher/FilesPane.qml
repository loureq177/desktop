import "../.."
import "../../Search.js" as Search
import Quickshell
import Quickshell.Io
import QtQuick

// Files and folders in the home folder, by name, as fd finds them while typing (hidden and
// git-ignored ones left out); every word must be in the path. Enter opens one.
LauncherPane {
	id: pane

	readonly property string home: Quickshell.env("HOME")
	readonly property var words: query.trim().toLowerCase().split(/\s+/).filter(w => w !== "")
	// fd's raw lines for `found`'s word; the rest of the words are matched here.
	property var paths: []
	property string found: ""
	property bool failed: false

	icon: "folder"
	placeholder: "Search files and folders in your home…"
	preferredHeight: list.preferredHeight
	footer: list.items[list.currentIndex]?.path.replace(home, "~") ?? ""

	function step(delta: int, repeat: bool): void {
		list.step(delta, repeat);
	}

	function activate(): void {
		list.activate();
	}

	function opened(): void {
		list.rewind();
	}

	function closed(): void {
		paths = [];
		found = "";
	}

	// The theme's icon for what the name says it is.
	function iconFor(name: string, folder: bool): string {
		if (folder)
			return "folder";
		var ext = name.includes(".") ? name.split(".").pop().toLowerCase() : "";
		if (ext === "pdf")
			return "application-pdf";
		if (["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp", "heic"].includes(ext))
			return "image-x-generic";
		if (["mp4", "mkv", "webm", "mov", "avi"].includes(ext))
			return "video-x-generic";
		if (["mp3", "flac", "ogg", "opus", "wav", "m4a"].includes(ext))
			return "audio-x-generic";
		if (["zip", "tar", "gz", "xz", "zst", "7z", "rar"].includes(ext))
			return "package-x-generic";
		return "text-x-generic";
	}

	// fd looks for the longest word; a new one waits for the last search to stop.
	readonly property string wanted: words.reduce((a, w) => w.length > a.length ? w : a, "")
	onWantedChanged: searchSoon.restart()
	onQueryChanged: list.reset()

	Timer {
		id: searchSoon
		interval: 60
		onTriggered: {
			if (fd.running)
				fd.running = false;
			else
				fd.search();
		}
	}

	Process {
		id: fd

		property string word: ""

		function search(): void {
			word = pane.wanted;
			if (word === "") {
				pane.paths = [];
				pane.found = "";
				return;
			}
			command = ["fd", "--full-path", "--fixed-strings", "--ignore-case", "--max-results", "5000", word, pane.home];
			running = true;
		}

		onExited: code => {
			pane.failed = code !== 0 && code !== 1 && word === pane.wanted;
			if (word !== pane.wanted)
				search();
		}

		stdout: StdioCollector {
			onStreamFinished: {
				if (fd.word !== pane.wanted)
					return;
				pane.paths = this.text.split("\n").filter(l => l !== "");
				pane.found = fd.word;
			}
		}
	}

	ResultList {
		id: list
		anchors.fill: parent
		emptyText: pane.failed ? "fd failed — is it installed?"
			: pane.words.length > 0 && pane.found === pane.wanted ? "Nothing matches" : ""

		// A name that starts with a word first, then one with a word in it, then the path
		// alone; the shallower and the shorter before the rest.
		items: {
			if (pane.found !== pane.wanted || pane.words.length === 0)
				return [];
			var home = pane.home + "/";
			var scored = [];
			for (var p of pane.paths) {
				var folder = p.endsWith("/");
				var full = folder ? p.slice(0, -1) : p;
				var rel = full.startsWith(home) ? full.slice(home.length) : full;
				var low = rel.toLowerCase();
				if (!pane.words.every(w => low.includes(w)))
					continue;
				var name = rel.split("/").pop();
				var best = 3;
				for (var w of pane.words) {
					var s = Search.fieldScore(name, w);
					if (s !== -1)
						best = Math.min(best, s);
				}
				scored.push({ score: best, depth: rel.split("/").length, name: name, rel: rel, full: full, folder: folder });
			}
			scored.sort((a, b) => a.score - b.score || a.depth - b.depth || a.name.length - b.name.length || a.rel.localeCompare(b.rel));
			return scored.slice(0, 60).map(f => ({
				label: f.name,
				subtitle: f.rel.includes("/") ? "~/" + f.rel.slice(0, f.rel.length - f.name.length - 1) : "~",
				icon: pane.iconFor(f.name, f.folder),
				path: f.full,
				run: () => Hypr.exec(["xdg-open", f.full])
			}));
		}
	}
}
