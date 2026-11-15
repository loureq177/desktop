pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// What the launcher ran, by key ("app:id", "cmd:id", "emoji:😀"): how often and when last,
// kept in usage.json. Recent uses weigh more, as in a browser's address bar.
Singleton {
	id: root

	property var uses: ({})
	readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell"

	function note(key: string): void {
		if (!key)
			return;
		var next = Object.assign({}, root.uses);
		next[key] = { n: (next[key]?.n ?? 0) + 1, last: Date.now() };
		root.uses = next;
		save.restart();
	}

	function score(key: string): real {
		var u = key ? root.uses[key] : null;
		if (!u)
			return 0;
		var days = (Date.now() - u.last) / 86400000;
		return u.n * (days < 1 ? 4 : days < 7 ? 2 : days < 30 ? 1 : 0.5);
	}

	Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dir])

	Timer {
		id: save
		interval: 1000
		onTriggered: file.setText(JSON.stringify(root.uses))
	}

	FileView {
		id: file
		path: root.dir + "/usage.json"
		blockLoading: true
		printErrors: false
		onLoaded: {
			try {
				root.uses = JSON.parse(text()) ?? {};
			} catch (e) {
				root.uses = {};
			}
		}
	}
}
