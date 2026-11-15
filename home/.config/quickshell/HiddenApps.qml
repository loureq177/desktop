pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Apps hidden from the launcher (Delete twice there): NoDisplay in the user's copy of their
// desktop entry, marked X-Shell-Hidden ("copy" made here, "added" to one of theirs).
Singleton {
	id: root

	// { id, name }, by name.
	property var list: []
	readonly property var ids: list.map(a => a.id)
	readonly property string dir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/applications"

	function hide(id: string): void {
		run('mkdir -p "$1"; dest="$1/$2.desktop"; mark() { sed "/^NoDisplay=/d; /^\\[Desktop Entry\\]/a NoDisplay=true\\nX-Shell-Hidden=$1"; }; '
			+ 'if [ -f "$dest" ]; then grep -q "^X-Shell-Hidden=" "$dest" || { mark added < "$dest" > "$dest.new" && mv "$dest.new" "$dest"; }; exit; fi; '
			+ 'IFS=:; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do [ -f "$d/applications/$2.desktop" ] && { mark copy < "$d/applications/$2.desktop" > "$dest"; exit; }; done; exit 1', id);
	}

	function unhide(id: string): void {
		run('f="$1/$2.desktop"; case "$(grep -m1 "^X-Shell-Hidden=" "$f")" in '
			+ 'X-Shell-Hidden=copy) rm -f "$f";; X-Shell-Hidden=added) sed -i "/^NoDisplay=true$/d; /^X-Shell-Hidden=/d" "$f";; esac', id);
	}

	function run(script: string, id: string): void {
		changer.command = ["sh", "-c", script, "sh", root.dir, id];
		changer.running = true;
	}

	function refresh(): void {
		lister.running = true;
	}

	Component.onCompleted: refresh()

	Process {
		id: changer
		onExited: root.refresh()
	}

	Process {
		id: lister
		command: ["sh", "-c", 'for f in "$1"/*.desktop; do grep -q "^X-Shell-Hidden=" "$f" 2>/dev/null || continue; '
			+ 'printf "%s\\t%s\\n" "$(basename "$f" .desktop)" "$(grep -m1 "^Name=" "$f" | cut -d= -f2-)"; done', "sh", root.dir]
		stdout: StdioCollector {
			onStreamFinished: root.list = this.text.split("\n").filter(l => l.includes("\t")).map(l => {
				var [id, name] = l.split("\t");
				return { id: id, name: name || id };
			}).sort((a, b) => a.name.localeCompare(b.name))
		}
	}
}
