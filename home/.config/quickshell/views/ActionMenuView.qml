import ".."
import "../widgets"
import "./actionmenu"
import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

SideDrawer {
	id: win

	panel: "actions"
	// "main", or the page of one tile ("wifi", "bluetooth", "capture").
	property string subView: "main"
	dismissOnEsc: subView === "main"
	cardWidth: 520
	readonly property int mainContentHeight: Math.min((contentCol.implicitHeight > 0 ? contentCol.implicitHeight : 430) + Theme.paddingCard * 2, win.height - Theme.notifTopMargin - 20)
	readonly property var subViews: ({ wifi: wifiSubView, bluetooth: btSubView, capture: captureSubView })
	readonly property int subViewHeight: Math.min((subViews[subView]?.preferredHeight ?? 0) + Theme.paddingCard * 2, 680, win.height - Theme.notifTopMargin - 20)
	cardHeight: subView === "main" ? mainContentHeight : subViewHeight

	readonly property bool brightnessReady: SystemStatus.brightness >= 0
	readonly property int rowVolume: 0
	readonly property int rowBrightness: win.brightnessReady ? 1 : -1
	readonly property int rowTilesStart: win.brightnessReady ? 2 : 1
	readonly property int rowWifiBt: rowTilesStart
	readonly property int rowBatteryCapture: rowTilesStart + 1
	readonly property int rowStayAwakeDnd: rowTilesStart + 2
	readonly property int maxRow: rowStayAwakeDnd

	property int navRow: 0
	property int navCol: 0

	function isCurrent(r, c) {
		return navRow === r && (c === undefined || navCol === c);
	}

	function select(r, c) {
		navRow = r;
		navCol = c !== undefined ? c : 0;
	}

	function focusSubView(): void {
		(subViews[subView] ?? contentCol).forceActiveFocus();
	}

	function backToMain(): void {
		subView = "main";
	}

	function toggleWifiRadio(): void {
		if (Networking.wifiHardwareEnabled)
			Networking.wifiEnabled = !Networking.wifiEnabled;
	}

	function toggleBtRadio(): void {
		if (SystemStatus.btAdapter)
			SystemStatus.btAdapter.enabled = !SystemStatus.btEnabled;
	}

	// The tile at a place of the grid, or the one a letter is printed on.
	function tileAt(r, c): Item {
		return Array.from(tileGrid.children).find(t => t.itemRow === r && t.itemCol === c) ?? null;
	}

	function tileForKey(key): Item {
		return Array.from(tileGrid.children).find(t => t.hotkey !== "" && key === t.hotkey.charCodeAt(0)) ?? null;
	}

	// Up and down through the sliders and the rows of tiles.
	function moveRow(delta): void {
		navRow = Math.max(0, Math.min(maxRow, navRow + delta));
		if (navRow < rowTilesStart)
			navCol = 0;
	}

	// Sideways a slider moves by 5%, a row of tiles to its other tile.
	function moveSide(delta): void {
		if (navRow === rowVolume)
			setVolume(volPct + 5 * delta);
		else if (navRow === rowBrightness)
			SystemStatus.setBrightness(SystemStatus.brightness + 5 * delta);
		else
			navCol = delta > 0 ? 1 : 0;
	}

	onOpened: mode => {
		win.subView = mode || "main";
		SystemStatus.readBrightness();
		if (win.subView === "main")
			select(0, 0);
		focusSubView();
	}
	onSubViewChanged: focusSubView()
	onFullyClosed: subView = "main"

	readonly property var audio: SystemStatus.sink?.audio ?? null
	readonly property bool volReady: SystemStatus.sink?.ready ?? false
	readonly property bool volMuted: audio?.muted ?? false
	readonly property int volPct: Math.round(Math.min(1, audio?.volume ?? 0) * 100)
	readonly property string volIcon: win.volMuted ? "volume-x" : (win.volPct <= 1 ? "volume" : (win.volPct <= 50 ? "volume-1" : "volume-2"))

	function setVolume(pct: real): void {
		if (!win.audio)
			return;
		win.audio.volume = Math.max(0, Math.min(100, Math.round(pct))) / 100;
		volumeSound.restart();
	}

	// One click once a drag or a run of key presses settles.
	Timer {
		id: volumeSound
		interval: 120
		onTriggered: {
			if (!win.volMuted)
				Quickshell.execDetached(["canberra-gtk-play", "-i", "audio-volume-change"]);
		}
	}

	function toggleMute(): void {
		if (win.audio)
			win.audio.muted = !win.audio.muted;
	}

	readonly property string wifiSubtitle: {
		if (!Networking.wifiHardwareEnabled)
			return "Blocked";
		if (!Networking.wifiEnabled)
			return "Off";
		return SystemStatus.wifiNetwork?.name || (SystemStatus.wifiUp ? "On" : "No connection");
	}

	readonly property string btSubtitle: {
		var connected = SystemStatus.btConnected;
		if (!SystemStatus.btAdapter)
			return "No adapter";
		if (connected.length > 1)
			return connected.length + " connected";
		if (connected.length === 1)
			return SystemStatus.deviceName(connected[0]);
		return SystemStatus.btEnabled ? "On" : "Off";
	}

	component ActionTile: Rectangle {
		id: stile

		property string icon: ""
		property string title: ""
		property string subtitle: ""
		property string hotkey: ""
		property bool active: false
		property color activeColor: Theme.accentBlue
		property bool hasDetails: false
		property bool hasToggleBadge: true
		property int itemRow: -1
		property int itemCol: -1
		readonly property bool isSelected: win.isCurrent(itemRow, itemCol)

		function isOverBadge(mx: real, my: real): bool {
			if (!hasToggleBadge) return false;
			var badgeRight = badge ? (badge.mapToItem(stile, badge.width, 0).x + 6) : 60;
			return mx >= 0 && mx < badgeRight;
		}

		// The badge of a tile with a page switches it, the rest opens the page.
		property bool badgeHovered: (stile.hasDetails && stile.hasToggleBadge)
			? (tileArea.containsMouse && stile.isOverBadge(tileArea.mouseX, tileArea.mouseY))
			: false

		signal iconClicked()
		signal bodyClicked()

		Layout.fillWidth: true
		Layout.preferredHeight: 76
		radius: Theme.roundingElement

		color: stile.active ? Theme.alpha(stile.activeColor, 0.18) : Theme.glass(Theme.bgMain)
		border.color: stile.active ? Theme.alpha(stile.activeColor, 0.3) : Theme.tileBorder
		border.width: 1

		Behavior on color { ColorAnimation { duration: Theme.animFast } }
		Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

		SelectionHighlight {
			selected: stile.isSelected
			color: stile.active ? Theme.alpha(stile.activeColor, 0.3) : Theme.selectionBg
		}

		HoverSelect {
			onSelected: win.select(stile.itemRow, stile.itemCol)
		}

		MouseArea {
			id: tileArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			z: 1
			onClicked: mouse => {
				win.select(stile.itemRow, stile.itemCol);
				if (stile.hasDetails && (!stile.hasToggleBadge || !stile.isOverBadge(mouse.x, mouse.y)))
					stile.bodyClicked();
				else
					stile.iconClicked();
			}
		}

		RowLayout {
			anchors.fill: parent
			anchors.leftMargin: 10
			anchors.rightMargin: 10
			spacing: 10

			Rectangle {
				id: badge
				Layout.alignment: Qt.AlignVCenter
				Layout.preferredWidth: 42
				Layout.preferredHeight: 42
				radius: Theme.roundingSubtle
				color: (stile.hasDetails && stile.hasToggleBadge)
					? (stile.active
						? (stile.badgeHovered ? Qt.lighter(stile.activeColor, 1.15) : stile.activeColor)
						: (stile.badgeHovered ? Theme.bgHover : Theme.glass(Theme.bgCard)))
					: "transparent"
				border.color: (stile.hasDetails && stile.hasToggleBadge)
					? (stile.active
						? (stile.badgeHovered ? Qt.lighter(stile.activeColor, 1.30) : "transparent")
						: (stile.badgeHovered ? Theme.textDim : Theme.border))
					: "transparent"
				border.width: 0

				Behavior on color { ColorAnimation { duration: Theme.animFast } }
				Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

				LineIcon {
					anchors.centerIn: parent
					name: stile.icon
					size: 22
					color: (stile.hasDetails && stile.hasToggleBadge)
						? (stile.active ? Theme.bgMain : (stile.badgeHovered ? Theme.textMain : Theme.textDim))
						: (stile.active ? stile.activeColor : (stile.isSelected ? Theme.textMain : Theme.textDim))
				}
			}

			ColumnLayout {
				Layout.fillWidth: true
				Layout.alignment: Qt.AlignVCenter
				spacing: 2

				StyledText {
					Layout.fillWidth: true
					text: stile.title
					font.bold: true
					elide: Text.ElideRight
				}

				StyledText {
					visible: stile.subtitle !== ""
					Layout.fillWidth: true
					text: stile.subtitle
					mono: true
					font.pixelSize: Theme.fontSizeSmall
					color: Theme.textDim
					elide: Text.ElideRight
				}
			}

			StyledText {
				visible: stile.hasDetails
				Layout.alignment: Qt.AlignVCenter
				text: "›"
				font.bold: true
				color: stile.isSelected ? Theme.accentBlue : Theme.textDim
			}
		}

		HotkeyHint {
			anchors.right: parent.right
			anchors.bottom: parent.bottom
			anchors.rightMargin: 10
			anchors.bottomMargin: 6
			key: stile.hotkey
			lit: stile.isSelected
			z: 2
		}
	}

	ColumnLayout {
		id: contentCol
		anchors.fill: parent
		spacing: 10
		focus: true
		visible: win.subView === "main"
		enabled: visible

		// Enter does what a click on a tile does, Space what a click on its
		// badge does (switching Wi-Fi or Bluetooth), O opens a tile's page.
		// The letter on a tile does the same as Enter from anywhere, Shift
		// and the letter the same as Space.
		Keys.onPressed: event => {
			if (event.isAutoRepeat)
				return;
			var tile = win.tileAt(win.navRow, win.navCol);
			switch (event.key) {
			case Qt.Key_J:
			case Qt.Key_Down:
				win.moveRow(1);
				break;
			case Qt.Key_K:
			case Qt.Key_Up:
				win.moveRow(-1);
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
				if (win.navRow === win.rowVolume)
					win.toggleMute();
				else if (tile)
					event.key === Qt.Key_Space ? tile.iconClicked() : tile.bodyClicked();
				break;
			case Qt.Key_O:
				if (tile?.hasDetails)
					tile.bodyClicked();
				break;
			case Qt.Key_Escape:
			case Qt.Key_Q:
				Panels.close("actions");
				break;
			default:
				tile = win.tileForKey(event.key);
				if (!tile)
					return;
				win.select(tile.itemRow, tile.itemCol);
				(event.modifiers & Qt.ShiftModifier) ? tile.iconClicked() : tile.bodyClicked();
			}
			event.accepted = true;
		}

		RowLayout {
			Layout.fillWidth: true
			Layout.preferredHeight: 32
			spacing: 10

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
			current: win.isCurrent(win.rowVolume)
			icon: win.volIcon
			label: win.volReady ? (win.volMuted ? "Muted" : win.volPct + "%") : "…"
			ready: win.volReady
			muted: win.volMuted
			value: win.volPct
			iconInteractive: true
			onSelectRequested: win.select(win.rowVolume, 0)
			onIconClicked: win.toggleMute()
			onScrubbed: v => win.setVolume(v)
		}

		SliderRow {
			id: briRow
			visible: win.brightnessReady
			current: win.isCurrent(win.rowBrightness)
			icon: "sun"
			label: SystemStatus.brightness + "%"
			ready: win.brightnessReady
			value: SystemStatus.brightness
			onSelectRequested: win.select(win.rowBrightness, 0)
			onScrubbed: v => SystemStatus.setBrightness(v)
		}

		GridLayout {
			id: tileGrid
			Layout.fillWidth: true
			columns: 2
			columnSpacing: 8
			rowSpacing: 8

			ActionTile {
				itemRow: win.rowWifiBt
				itemCol: 0
				hotkey: "W"
				icon: SystemStatus.wifiUp ? "wifi" : "wifi-off"
				title: "Wi-Fi"
				subtitle: win.wifiSubtitle
				active: Networking.wifiEnabled
				hasDetails: true
				onIconClicked: win.toggleWifiRadio()
				onBodyClicked: win.subView = "wifi"
			}

			ActionTile {
				itemRow: win.rowWifiBt
				itemCol: 1
				hotkey: "B"
				icon: SystemStatus.btIcon
				title: "Bluetooth"
				subtitle: win.btSubtitle
				active: SystemStatus.btEnabled
				hasDetails: true
				onIconClicked: win.toggleBtRadio()
				onBodyClicked: win.subView = "bluetooth"
			}

			ActionTile {
				itemRow: win.rowBatteryCapture
				itemCol: 0
				hotkey: "S"
				icon: "leaf"
				title: "Battery saver"
				subtitle: SystemStatus.powerSaveActive ? "60 Hz" : ""
				active: SystemStatus.powerSaveActive
				activeColor: Theme.accentGreen
				hasDetails: false
				onIconClicked: Actions.togglePowerSave()
				onBodyClicked: Actions.togglePowerSave()
			}

			ActionTile {
				itemRow: win.rowBatteryCapture
				itemCol: 1
				hotkey: "C"
				icon: SystemStatus.recording ? "circle-stop" : "camera"
				title: "Capture"
				subtitle: SystemStatus.recording ? "Recording" : ""
				active: SystemStatus.recording
				activeColor: Theme.critical
				hasDetails: true
				hasToggleBadge: false
				onIconClicked: win.subView = "capture"
				onBodyClicked: win.subView = "capture"
			}

			ActionTile {
				itemRow: win.rowStayAwakeDnd
				itemCol: 0
				hotkey: "A"
				icon: "coffee"
				title: "Keep awake"
				subtitle: ""
				active: SystemStatus.awakeActive
				hasDetails: false
				onIconClicked: Actions.toggleAwake()
				onBodyClicked: Actions.toggleAwake()
			}

			ActionTile {
				itemRow: win.rowStayAwakeDnd
				itemCol: 1
				hotkey: "D"
				icon: Notifications.dnd ? "bell-off" : "bell"
				title: "Do not disturb"
				subtitle: ""
				active: Notifications.dnd
				activeColor: Theme.warning
				hasDetails: false
				onIconClicked: Notifications.dnd = !Notifications.dnd
				onBodyClicked: Notifications.dnd = !Notifications.dnd
			}
		}
	}

	WifiSubView {
		id: wifiSubView
		anchors.fill: parent
		visible: win.subView === "wifi"
		enabled: visible
		focus: visible
		onBackRequested: win.backToMain()
	}

	BluetoothSubView {
		id: btSubView
		anchors.fill: parent
		visible: win.subView === "bluetooth"
		enabled: visible
		focus: visible
		onBackRequested: win.backToMain()
	}

	CaptureSubView {
		id: captureSubView
		anchors.fill: parent
		visible: win.subView === "capture"
		enabled: visible
		focus: visible
		onBackRequested: win.backToMain()
	}
}
