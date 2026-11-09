import "../.."
import "../../Search.js" as Search
import Quickshell
import Quickshell.Io
import QtQuick

// Files and folders in the home folder, by name, as fd finds them while typing (hidden and
// git-ignored ones left out); every word must be in the path. `items` are launcher rows.
Item {
	id: root

	property string query: ""
	property int limit: 6
	readonly property string home: Quickshell.env("HOME")
	readonly property var words: query.trim().toLowerCase().split(/\s+/).filter(w => w !== "")
	// fd's lines for `found`'s word, taken apart once; the rest of the words are matched here.
	property var paths: []
	property string found: ""
	property bool failed: false
	// Typed, and fd has not answered yet.
	readonly property bool searching: wanted !== "" && found !== wanted && !failed

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
	// Emptied at once, with the query: one new list, not a second one later.
	onWantedChanged: {
		if (wanted !== "") {
			searchSoon.restart();
			return;
		}
		searchSoon.stop();
		fd.running = false;
		paths = [];
		found = "";
	}

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
			word = root.wanted;
			if (word === "") {
				root.paths = [];
				root.found = "";
				return;
			}
			command = ["fd", "--full-path", "--fixed-strings", "--ignore-case", "--max-results", "1000", word, root.home];
			running = true;
		}

		onExited: code => {
			root.failed = code !== 0 && code !== 1 && word === root.wanted;
			if (word !== root.wanted)
				search();
		}

		stdout: StdioCollector {
			onStreamFinished: {
				if (fd.word !== root.wanted)
					return;
				var prefix = root.home + "/";
				root.paths = this.text.split("\n").filter(l => l !== "").map(p => {
					var folder = p.endsWith("/");
					var full = folder ? p.slice(0, -1) : p;
					var rel = full.startsWith(prefix) ? full.slice(prefix.length) : full;
					var parts = rel.split("/");
					return { full: full, rel: rel, low: rel.toLowerCase(), name: parts[parts.length - 1], depth: parts.length, folder: folder };
				});
				root.found = fd.word;
			}
		}
	}

	// A name that starts with a word first, then one with a word in it, then the path
	// alone; the shallower and the shorter before the rest. Until fd answers, the last
	// search's paths with the new words: the list does not empty at each key.
	readonly property var matches: {
		if (words.length === 0)
			return [];
		var scored = [];
		for (var p of paths) {
			if (!words.every(w => p.low.includes(w)))
				continue;
			var best = 3;
			for (var w of words) {
				var s = Search.fieldScore(p.name, w);
				if (s !== -1)
					best = Math.min(best, s);
			}
			scored.push(Object.assign({ score: best }, p));
		}
		// Not localeCompare: thousands of paths on a two-letter word.
		scored.sort((a, b) => a.score - b.score || a.depth - b.depth || a.name.length - b.name.length || (a.rel < b.rel ? -1 : a.rel > b.rel ? 1 : 0));
		return scored;
	}

	readonly property var items: matches.slice(0, limit).map(f => ({
		label: f.name,
		subtitle: f.rel.includes("/") ? "~/" + f.rel.slice(0, f.rel.length - f.name.length - 1) : "~",
		icon: root.iconFor(f.name, f.folder),
		heading: "files",
		path: f.full,
		run: () => Hypr.exec(["xdg-open", f.full])
	}))
}
