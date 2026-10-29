import "../.."
import QtQuick

// The power menu: a letter runs its command; what ends the session needs it twice.
LauncherPane {
	id: pane

	readonly property var commands: Commands.all.filter(c => c.group === "session")

	icon: "power"
	placeholder: commands.map(c => c.key + " " + c.name.toLowerCase()).join(" · ")
	preferredHeight: list.preferredHeight

	function step(delta: int, repeat: bool): void {
		list.step(delta, repeat);
	}

	function activate(): void {
		list.activate();
	}

	function opened(): void {
		list.reset();
	}

	onQueryChanged: {
		if (query === "")
			return;
		var key = query.slice(-1).toUpperCase();
		pane.queryRequested("");
		var index = commands.findIndex(c => c.key === key);
		if (index < 0)
			return;
		list.currentIndex = index;
		list.activate();
	}

	ResultList {
		id: list
		anchors.fill: parent

		items: pane.commands.map(c => ({
			label: c.name,
			subtitle: c.desc,
			lineIcon: c.icon,
			chord: c.key,
			confirm: c.confirm,
			run: c.run
		}))
	}
}
