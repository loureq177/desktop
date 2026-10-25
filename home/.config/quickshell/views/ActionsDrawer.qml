import ".."
import "../widgets"
import "./actionmenu"
import QtQuick
import QtQuick.Layouts

// Volume, brightness and the switches of the desktop, with a page of their
// own for Wi-Fi, Bluetooth and Capture.
Drawer {
	id: win

	name: "actions"
	cardWidth: 520
	// "main", or the page of one tile ("wifi", "bluetooth", "capture").
	property string subView: "main"
	readonly property var pages: ({ main: mainPage, wifi: wifiPage, bluetooth: btPage, capture: capturePage })
	contentHeight: pages[subView].implicitHeight

	// The keyboard's place: a slider's row, or a row and column of the tiles.
	property int navRow: 0
	property int navCol: 0
	readonly property var sliders: Brightness.percent >= 0 ? [volRow, briRow] : [volRow]
	readonly property int rowCount: sliders.length + Math.ceil(tileGrid.children.length / 2)

	function tileAt(r: int, c: int): Item {
		return r < sliders.length ? null : tileGrid.children[(r - sliders.length) * 2 + c] ?? null;
	}

	function selectTile(tile: Item): void {
		var i = Array.from(tileGrid.children).indexOf(tile);
		navRow = sliders.length + Math.floor(i / 2);
		navCol = i % 2;
	}

	// Sideways a slider moves by 5%, a row of tiles to its other tile.
	function moveSide(delta: int): void {
		if (navRow === 0)
			Audio.setVolume(Audio.volume + 5 * delta);
		else if (navRow < sliders.length)
			Brightness.setPercent(Brightness.percent + 5 * delta);
		else
			navCol = delta > 0 ? 1 : 0;
	}

	onOpened: mode => {
		subView = mode || "main";
		Brightness.read();
		navRow = 0;
		navCol = 0;
		pages[subView].forceActiveFocus();
	}
	onSubViewChanged: pages[subView].forceActiveFocus()

	// A switch, a page, or a switch with a page: its badge flips the switch,
	// the rest of it opens the page. `command` fills in what the tile shows
	// and does from Commands.
	component Tile: Rectangle {
		id: tile

		property string command: ""
		readonly property var cmd: Commands.get(command)
		property string key: ""
		property string title: cmd?.name ?? ""
		property string subtitle: ""
		property string icon: cmd?.icon ?? ""
		property bool active: cmd?.active ?? false
		property color tint: cmd?.tint ?? Theme.accentBlue
		property string page: ""
		property var toggle: cmd?.run ?? null
		readonly property bool switchable: page !== "" && toggle !== null
		readonly property bool selected: win.tileAt(win.navRow, win.navCol) === tile
		readonly property bool badgeHovered: badgeArea.containsMouse

		function open(): void {
			if (page !== "")
				win.subView = page;
			else
				toggle();
		}

		function flip(): void {
			if (toggle)
				toggle();
			else
				open();
		}

		Layout.fillWidth: true
		Layout.preferredHeight: 76
		radius: Theme.roundingElement
		color: active ? Theme.alpha(tint, 0.18) : Theme.glass(Theme.bgMain)
		border.color: active ? Theme.alpha(tint, 0.3) : Theme.tileBorder
		border.width: 1

		Behavior on color { ColorAnimation { duration: Theme.animFast } }
		Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

		SelectionHighlight {
			selected: tile.selected
		}

		HoverSelect {
			onSelected: win.selectTile(tile)
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor
			onClicked: {
				win.selectTile(tile);
				tile.open();
			}
		}

		RowLayout {
			anchors.fill: parent
			anchors.leftMargin: 10
			anchors.rightMargin: 10
			spacing: 10

			Rectangle {
				Layout.preferredWidth: 42
				Layout.preferredHeight: 42
				radius: Theme.roundingSubtle
				color: !tile.switchable ? "transparent"
					: tile.active ? (tile.badgeHovered ? Qt.lighter(tile.tint, 1.15) : tile.tint)
					: tile.badgeHovered ? Theme.bgHover : Theme.glass(Theme.bgCard)

				Behavior on color { ColorAnimation { duration: Theme.animFast } }

				LineIcon {
					anchors.centerIn: parent
					name: tile.icon
					size: 22
					color: tile.switchable ? (tile.active ? Theme.bgMain : tile.badgeHovered ? Theme.textMain : Theme.textDim)
						: tile.active ? tile.tint : tile.selected ? Theme.textMain : Theme.textDim
				}

				MouseArea {
					id: badgeArea
					anchors.fill: parent
					enabled: tile.switchable
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: {
						win.selectTile(tile);
						tile.flip();
					}
				}
			}

			ColumnLayout {
				Layout.fillWidth: true
				spacing: 2

				StyledText {
					Layout.fillWidth: true
					text: tile.title
					font.bold: true
					elide: Text.ElideRight
				}

				StyledText {
					visible: text !== ""
					Layout.fillWidth: true
					text: tile.subtitle
					mono: true
					font.pixelSize: Theme.fontSizeSmall
					color: Theme.textDim
					elide: Text.ElideRight
				}
			}

			StyledText {
				visible: tile.page !== ""
				text: "›"
				font.bold: true
				color: tile.selected ? Theme.textMain : Theme.textDim
			}
		}

		HotkeyHint {
			anchors.right: parent.right
			anchors.bottom: parent.bottom
			anchors.rightMargin: 10
			anchors.bottomMargin: 6
			key: tile.key
			lit: tile.selected
		}
	}

	ColumnLayout {
		id: mainPage
		anchors.fill: parent
		spacing: 10
		focus: true
		visible: win.subView === "main"

		// Enter does what a click on a tile does, Space what a click on its
		// badge does (switching Wi-Fi or Bluetooth), O opens a tile's page. The
		// letter on a tile does the same as Enter from anywhere, Shift and the
		// letter the same as Space. Held, only the moves repeat: a slider keeps
		// going, a switch does not flicker.
		Keys.onPressed: event => {
			var moves = [Qt.Key_H, Qt.Key_J, Qt.Key_K, Qt.Key_L, Qt.Key_Left, Qt.Key_Down, Qt.Key_Up, Qt.Key_Right];
			if (event.isAutoRepeat && !moves.includes(event.key))
				return;
			var tile = win.tileAt(win.navRow, win.navCol);
			switch (event.key) {
			case Qt.Key_J:
			case Qt.Key_Down:
			case Qt.Key_K:
			case Qt.Key_Up:
				var down = event.key === Qt.Key_J || event.key === Qt.Key_Down;
				win.navRow = Math.max(0, Math.min(win.rowCount - 1, win.navRow + (down ? 1 : -1)));
				break;
			case Qt.Key_H:
			case Qt.Key_Left:
				win.moveSide(-1);
				break;
			case Qt.Key_L:
			case Qt.Key_Right:
				win.moveSide(1);
				break;
			case Qt.Key_Return:
			case Qt.Key_Enter:
			case Qt.Key_Space:
				if (win.navRow === 0)
					Audio.toggleMute();
				else if (tile)
					event.key === Qt.Key_Space ? tile.flip() : tile.open();
				break;
			case Qt.Key_O:
				if (tile?.page)
					tile.open();
				break;
			case Qt.Key_Q:
				Panels.close("actions");
				break;
			default:
				tile = Array.from(tileGrid.children).find(t => t.key !== "" && event.key === t.key.charCodeAt(0));
				if (!tile)
					return;
				win.selectTile(tile);
				(event.modifiers & Qt.ShiftModifier) ? tile.flip() : tile.open();
			}
			event.accepted = true;
		}

		RowLayout {
			Layout.fillWidth: true
			Layout.preferredHeight: 32

			StyledText {
				Layout.fillWidth: true
				text: "Actions"
				font.pixelSize: Theme.fontSizeLarge
				font.bold: true
			}

			CloseButton {
				onClicked: Panels.close("actions")
			}
		}

		SliderRow {
			id: volRow
			current: win.navRow === 0
			icon: Audio.icon
			label: !ready ? "…" : Audio.muted ? "Muted" : Audio.volume + "%"
			ready: Audio.ready
			muted: Audio.muted
			value: Audio.volume
			iconInteractive: true
			onSelectRequested: win.navRow = 0
			onIconClicked: Audio.toggleMute()
			onScrubbed: v => Audio.setVolume(v)
		}

		SliderRow {
			id: briRow
			visible: Brightness.percent >= 0
			current: win.navRow === 1 && visible
			icon: "sun"
			label: Brightness.percent + "%"
			ready: visible
			value: Brightness.percent
			onSelectRequested: win.navRow = 1
			onScrubbed: v => Brightness.setPercent(v)
		}

		GridLayout {
			id: tileGrid
			Layout.fillWidth: true
			columns: 2
			columnSpacing: 8
			rowSpacing: 8

			Tile {
				key: "W"
				title: "Wi-Fi"
				icon: Net.wifiUp ? "wifi" : "wifi-off"
				subtitle: Net.wifiStatus
				active: Net.wifiOn
				page: "wifi"
				toggle: () => Net.toggleWifi()
			}

			Tile {
				key: "B"
				title: "Bluetooth"
				icon: Bt.icon
				subtitle: Bt.status
				active: Bt.enabled
				page: "bluetooth"
				toggle: () => Bt.toggle()
			}

			Tile {
				key: "S"
				command: "powersave"
				subtitle: active ? "60 Hz" : ""
			}

			Tile {
				key: "C"
				title: "Capture"
				icon: Modes.recording ? "circle-stop" : "camera"
				subtitle: Modes.recording ? "Recording" : ""
				active: Modes.recording
				tint: Theme.critical
				page: "capture"
			}

			Tile {
				key: "A"
				command: "awake"
			}

			Tile {
				key: "D"
				command: "dnd"
				icon: active ? "bell-off" : "bell"
			}
		}
	}

	WifiSubView {
		id: wifiPage
		anchors.fill: parent
		visible: win.subView === "wifi"
		onBackRequested: win.subView = "main"
	}

	BluetoothSubView {
		id: btPage
		anchors.fill: parent
		visible: win.subView === "bluetooth"
		onBackRequested: win.subView = "main"
	}

	CaptureSubView {
		id: capturePage
		anchors.fill: parent
		visible: win.subView === "capture"
		onBackRequested: win.subView = "main"
	}
}
