import "../.."
import "../../widgets"
import "../../widgets/ListNav.js" as ListNav
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// Every open window, on any workspace or special, most recently used first, with its live
// picture: Enter or a click goes to it, Delete or a middle click closes it.
LauncherPane {
	id: pane

	// { address, title, name, icon, place, toplevel }
	property var windows: []
	// Windows are asked for and captured only from opened() to closed().
	property bool active: false
	// Where to go once the launcher has let go of the keyboard: until then Hyprland refuses
	// any window the focus.
	property string goingTo: ""

	icon: "app-window"
	placeholder: "Search open windows, Delete closes one…"
	grid: true
	preferredHeight: count === 0 ? 72 : Math.ceil(count / columns) * cellHeight

	readonly property var items: {
		var needle = query.trim().toLowerCase();
		return windows.filter(w => (w.name + " " + w.title + " " + w.place).toLowerCase().includes(needle));
	}
	readonly property int count: items.length
	readonly property int columns: 3
	readonly property int inset: 3
	readonly property int labelHeight: 34
	readonly property real cellWidth: width / columns
	readonly property real pictureHeight: (cellWidth - inset * 2) * 10 / 16
	readonly property real cellHeight: pictureHeight + labelHeight + inset * 2

	function step(delta: int, repeat: bool): void {
		cells.currentIndex = ListNav.wrap(cells.currentIndex, delta * columns, count, repeat);
	}

	function stepColumn(delta: int, repeat: bool): void {
		cells.currentIndex = ListNav.wrap(cells.currentIndex, delta, count, repeat);
	}

	function activate(): void {
		cells.activated(cells.currentIndex);
	}

	function removeValue(): void {
		closeWindow(cells.currentIndex);
	}

	// The window before the one in use: the first one is where you already are.
	function opened(): void {
		active = true;
		goingTo = "";
		cells.currentIndex = 1;
		cells.positionViewAtBeginning();
		Hyprland.refreshToplevels();
		refresh();
	}

	function closed(): void {
		active = false;
		windows = [];
	}

	// The launcher is gone from the screen.
	function arrive(): void {
		if (goingTo !== "")
			Hypr.dispatch("hl.dsp.focus({ window = " + Hypr.quote("address:" + goingTo) + " })");
		goingTo = "";
	}

	function closeWindow(index: int): void {
		var w = items[index];
		if (w)
			Hypr.dispatch("hl.dsp.window.close({ window = " + Hypr.quote("address:" + w.address) + " })");
	}

	function iconOf(special: var, entry: var): string {
		var name = special?.appIcon && special.appIcon !== "web-browser" ? special.appIcon : entry?.icon ?? "";
		if (name.startsWith("icons/"))
			return "file://" + Quickshell.shellDir + "/" + name;
		return name ? Quickshell.iconPath(name, true) : "";
	}

	function refresh(): void {
		if (clients.running)
			refreshTimer.restart();
		else
			clients.running = true;
	}

	onQueryChanged: cells.currentIndex = 0

	Timer {
		id: refreshTimer
		interval: 50
		onTriggered: pane.refresh()
	}

	Connections {
		target: Hyprland
		enabled: pane.active
		function onRawEvent(ev) {
			if (["openwindow", "closewindow", "windowtitlev2", "movewindowv2"].includes(ev.name)) {
				Hyprland.refreshToplevels();
				refreshTimer.restart();
			}
		}
	}

	Process {
		id: clients
		command: ["hyprctl", "clients", "-j"]
		stdout: StdioCollector {
			onStreamFinished: {
				if (!pane.active)
					return;
				var all = [];
				try {
					all = JSON.parse(this.text);
				} catch (e) {
					return;
				}
				var keep = cells.currentIndex;
				pane.windows = all.filter(c => c.mapped && !c.hidden).sort((a, b) => a.focusHistoryID - b.focusHistoryID).map(c => {
					var specialName = c.workspace.name.startsWith("special:") ? c.workspace.name.slice(8) : "";
					var special = specialName ? Specials.find(specialName) : null;
					var entry = DesktopEntries.heuristicLookup(c.class);
					return {
						address: c.address,
						title: c.title,
						name: special?.app ?? entry?.name ?? c.class,
						icon: pane.iconOf(special, entry),
						place: special?.title ?? specialName,
						toplevel: Hyprland.toplevels.values.find(t => "0x" + t.address === c.address) ?? null
					};
				});
				cells.currentIndex = Math.min(keep, Math.max(pane.count - 1, 0));
			}
		}
	}

	GridView {
		id: cells

		signal activated(int index)

		anchors.fill: parent
		clip: true
		cellWidth: pane.cellWidth
		cellHeight: pane.cellHeight
		model: pane.items
		highlightFollowsCurrentItem: false
		onCurrentIndexChanged: scrolling.reveal(currentIndex)
		onActivated: index => {
			var w = pane.items[index];
			if (!w)
				return;
			pane.goingTo = w.address;
			Panels.close("launcher");
		}

		ListHighlight {
			view: cells
		}

		WheelScroll {
			id: scrolling
			flickable: cells
		}

		delegate: ListRow {
			id: cell

			required property var modelData

			width: pane.cellWidth
			height: pane.cellHeight
			inset: pane.inset

			ScreencopyView {
				anchors.horizontalCenter: parent.horizontalCenter
				y: pane.inset + (pane.pictureHeight - height) / 2
				captureSource: cell.modelData.toplevel?.wayland ?? null
				live: pane.active
				constraintSize: Qt.size(pane.cellWidth - pane.inset * 4, pane.pictureHeight - 4)
			}

			Row {
				anchors.left: parent.left
				anchors.right: parent.right
				anchors.bottom: parent.bottom
				anchors.leftMargin: 10
				anchors.rightMargin: 10
				height: pane.labelHeight
				spacing: 8

				IconImage {
					anchors.verticalCenter: parent.verticalCenter
					visible: cell.modelData.icon !== ""
					implicitSize: 18
					source: cell.modelData.icon
				}

				StyledText {
					anchors.verticalCenter: parent.verticalCenter
					width: parent.width - 26
					text: cell.modelData.title || cell.modelData.name
					font.pixelSize: Theme.fontSizeSmall
					elide: Text.ElideRight
				}
			}

			MouseArea {
				anchors.fill: parent
				acceptedButtons: Qt.MiddleButton
				onClicked: pane.closeWindow(cell.index)
			}
		}
	}

	StyledText {
		visible: pane.count === 0 && !clients.running
		anchors.centerIn: parent
		font.pixelSize: Theme.fontSizeSmall
		color: Theme.textDim
		text: pane.windows.length === 0 ? "No open windows" : "Nothing matches"
	}
}
