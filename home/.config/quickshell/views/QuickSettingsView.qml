import ".."
import "../widgets"
import "./quicksettings"
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

SideDrawer {
	id: win

	panel: "quicksettings"
	// "main", the page of one tile ("wifi", "bluetooth", "capture"), or "power".
	property string subView: "main"
	dismissOnEsc: subView === "main"
	cardWidth: 520
	readonly property int mainContentHeight: Math.min((contentCol.implicitHeight > 0 ? contentCol.implicitHeight : 430) + Theme.paddingCard * 2, win.height - Theme.notifTopMargin - 20)
	readonly property int currentSubViewHeight: {
		if (subView === "wifi")
			return wifiSubView.preferredHeight + Theme.paddingCard * 2;
		if (subView === "bluetooth")
			return btSubView.preferredHeight + Theme.paddingCard * 2;
		if (subView === "capture")
			return captureSubView.preferredHeight + Theme.paddingCard * 2;
		if (subView === "power")
			return powerSubView.preferredHeight + Theme.paddingCard * 2;
		return 540;
	}
	readonly property int subViewHeight: Math.min(currentSubViewHeight, Math.min(680, win.height - Theme.notifTopMargin - 20))
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
		switch (subView) {
		case "main": contentCol.forceActiveFocus(); break;
		case "wifi": wifiSubView.forceActiveFocus(); break;
		case "bluetooth": btSubView.forceActiveFocus(); break;
		case "capture": captureSubView.forceActiveFocus(); break;
		case "power": powerSubView.forceActiveFocus(); break;
		}
	}

	function backToMain(): void {
		subView = "main";
	}

	function togglePowerSave(): void {
		Quickshell.execDetached(["sh", "-c", "~/.local/bin/power-save"]);
	}

	function toggleAwake(): void {
		Quickshell.execDetached(["sh", "-c", "~/.local/bin/awake-toggle"]);
	}

	function toggleWifiRadio(): void {
		if (Networking.wifiHardwareEnabled)
			Networking.wifiEnabled = !Networking.wifiEnabled;
	}

	function toggleBtRadio(): void {
		if (win.btAdapter)
			win.btAdapter.enabled = !win.btAdapter.enabled;
	}

	function activateTile(r, c, viaIcon): void {
		if (r === rowWifiBt) {
			if (viaIcon)
				c === 0 ? toggleWifiRadio() : toggleBtRadio();
			else
				win.subView = c === 0 ? "wifi" : "bluetooth";
		} else if (r === rowBatteryCapture) {
			if (c === 0)
				togglePowerSave();
			else
				win.subView = "capture";
		} else if (r === rowStayAwakeDnd) {
			if (c === 0)
				toggleAwake();
			else
				Notifications.dnd = !Notifications.dnd;
		}
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

	readonly property var wifiDevice: SystemStatus.wifiDevice
	readonly property bool wifiUp: win.wifiDevice?.connected ?? false
	readonly property string activeSsid: (win.wifiDevice?.networks?.values ?? []).find(n => n?.connected)?.name ?? ""
	readonly property string wifiSubtitle: {
		if (!Networking.wifiHardwareEnabled)
			return "Blocked";
		if (!Networking.wifiEnabled)
			return "Off";
		return win.activeSsid !== "" ? win.activeSsid : (win.wifiUp ? "On" : "No connection");
	}

	readonly property var btAdapter: Bluetooth.defaultAdapter
	readonly property bool btEnabled: win.btAdapter?.enabled ?? false
	readonly property var btConnected: (win.btAdapter?.devices?.values ?? []).filter(d => d.connected)
	readonly property string btSubtitle: {
		if (!win.btAdapter)
			return "No adapter";
		if (win.btConnected.length > 1)
			return win.btConnected.length + " connected";
		if (win.btConnected.length === 1)
			return win.btConnected[0].name || win.btConnected[0].deviceName || "Connected";
		return win.btEnabled ? "On" : "Off";
	}

	component SamsungTile: Rectangle {
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

		color: stile.active ? Theme.alpha(stile.activeColor, 0.18) : Theme.inset(Theme.bgMain)
		border.color: stile.active ? Theme.alpha(stile.activeColor, 0.3) : Theme.tileBorder
		border.width: 1

		Behavior on color { ColorAnimation { duration: 120 } }
		Behavior on border.color { ColorAnimation { duration: 120 } }

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
						: (stile.badgeHovered ? Theme.bgHover : Theme.inset(Theme.bgCard)))
					: "transparent"
				border.color: (stile.hasDetails && stile.hasToggleBadge)
					? (stile.active
						? (stile.badgeHovered ? Qt.lighter(stile.activeColor, 1.30) : "transparent")
						: (stile.badgeHovered ? Theme.textDim : Theme.border))
					: "transparent"
				border.width: 0

				Behavior on color { ColorAnimation { duration: 140 } }
				Behavior on border.color { ColorAnimation { duration: 120 } }

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

				Text {
					Layout.fillWidth: true
					text: stile.title
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSizeSmall + 2
					font.bold: true
					color: Theme.textMain
					elide: Text.ElideRight
				}

				Text {
					visible: stile.subtitle !== ""
					Layout.fillWidth: true
					text: stile.subtitle
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeSmall
					color: Theme.textDim
					elide: Text.ElideRight
				}
			}

			Text {
				visible: stile.hasDetails
				Layout.alignment: Qt.AlignVCenter
				text: "›"
				font.family: Theme.fontFamily
				font.pixelSize: 16
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

		Keys.onPressed: event => {
			if (event.isAutoRepeat) return;
			if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
				var nextRow = win.navRow + 1;
				if (nextRow === win.rowBrightness && !win.brightnessReady)
					nextRow++;
				win.navRow = Math.min(win.maxRow, nextRow);
				if (win.navRow === win.rowVolume || win.navRow === win.rowBrightness)
					win.navCol = 0;
				event.accepted = true;
			} else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
				var prevRow = win.navRow - 1;
				if (prevRow === win.rowBrightness && !win.brightnessReady)
					prevRow--;
				win.navRow = Math.max(0, prevRow);
				if (win.navRow === win.rowVolume || win.navRow === win.rowBrightness)
					win.navCol = 0;
				event.accepted = true;
			} else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
				if (win.navRow === win.rowVolume) {
					win.setVolume(win.volPct - 5);
				} else if (win.navRow === win.rowBrightness && win.brightnessReady) {
					SystemStatus.setBrightness(SystemStatus.brightness - 5);
				} else if (win.navRow >= win.rowTilesStart && win.navRow <= win.maxRow) {
					win.navCol = 0;
				}
				event.accepted = true;
			} else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
				if (win.navRow === win.rowVolume) {
					win.setVolume(win.volPct + 5);
				} else if (win.navRow === win.rowBrightness && win.brightnessReady) {
					SystemStatus.setBrightness(SystemStatus.brightness + 5);
				} else if (win.navRow >= win.rowTilesStart) {
					win.navCol = 1;
				}
				event.accepted = true;
			} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
				if (win.navRow === win.rowVolume)
					win.toggleMute();
				else
					win.activateTile(win.navRow, win.navCol, false);
				event.accepted = true;
			} else if (event.key === Qt.Key_Space) {
				if (win.navRow === win.rowVolume)
					win.toggleMute();
				else
					win.activateTile(win.navRow, win.navCol, true);
				event.accepted = true;
			} else if (event.key === Qt.Key_O) {
				if (win.navRow === win.rowWifiBt || (win.navRow === win.rowBatteryCapture && win.navCol === 1))
					win.activateTile(win.navRow, win.navCol, false);
				event.accepted = true;
			} else if (event.key === Qt.Key_C) {
				win.subView = "capture";
				win.select(win.rowBatteryCapture, 1);
				event.accepted = true;
			} else if (event.key === Qt.Key_W) {
				if (event.modifiers & Qt.ShiftModifier) {
					win.toggleWifiRadio();
					win.select(win.rowWifiBt, 0);
				} else {
					win.subView = "wifi";
				}
				event.accepted = true;
			} else if (event.key === Qt.Key_B) {
				if (event.modifiers & Qt.ShiftModifier) {
					win.toggleBtRadio();
					win.select(win.rowWifiBt, 1);
				} else {
					win.subView = "bluetooth";
				}
				event.accepted = true;
			} else if (event.key === Qt.Key_S) {
				win.togglePowerSave();
				win.select(win.rowBatteryCapture, 0);
				event.accepted = true;
			} else if (event.key === Qt.Key_A) {
				win.toggleAwake();
				win.select(win.rowStayAwakeDnd, 0);
				event.accepted = true;
			} else if (event.key === Qt.Key_D) {
				Notifications.dnd = !Notifications.dnd;
				win.select(win.rowStayAwakeDnd, 1);
				event.accepted = true;
			} else if (event.key === Qt.Key_P) {
				win.subView = "power";
				event.accepted = true;
			} else if (event.key === Qt.Key_M) {
				win.toggleMute();
				win.select(win.rowVolume, 0);
				event.accepted = true;
			} else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
				Panels.close("quicksettings");
				event.accepted = true;
			}
		}

		RowLayout {
			Layout.fillWidth: true
			Layout.preferredHeight: 32
			spacing: 10

			Text {
				Layout.fillWidth: true
				text: "Quick settings"
				font.family: Theme.fontFamily
				font.pixelSize: Theme.fontSize + 1
				font.bold: true
				color: Theme.textMain
			}

			IconButton {
				icon: "power"
				hotkey: "P"
				onClicked: win.subView = "power"
			}

			CloseButton {
				onClicked: Panels.close("quicksettings")
			}
		}

		SliderRow {
			id: volRow
			current: win.isCurrent(win.rowVolume)
			icon: win.volIcon
			hotkey: "M"
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
			Layout.fillWidth: true
			columns: 2
			columnSpacing: 8
			rowSpacing: 8

			SamsungTile {
				itemRow: win.rowWifiBt
				itemCol: 0
				hotkey: "W"
				icon: win.wifiUp ? "wifi" : "wifi-off"
				title: "Wi-Fi"
				subtitle: win.wifiSubtitle
				active: Networking.wifiEnabled
				hasDetails: true
				onIconClicked: win.toggleWifiRadio()
				onBodyClicked: win.subView = "wifi"
			}

			SamsungTile {
				itemRow: win.rowWifiBt
				itemCol: 1
				hotkey: "B"
				icon: !win.btEnabled ? "bluetooth-off" : (win.btConnected.length > 0 ? "bluetooth-connected" : "bluetooth")
				title: "Bluetooth"
				subtitle: win.btSubtitle
				active: win.btEnabled
				hasDetails: true
				onIconClicked: win.toggleBtRadio()
				onBodyClicked: win.subView = "bluetooth"
			}

			SamsungTile {
				itemRow: win.rowBatteryCapture
				itemCol: 0
				hotkey: "S"
				icon: "leaf"
				title: "Battery saver"
				subtitle: SystemStatus.powerSaveActive ? "60 Hz" : ""
				active: SystemStatus.powerSaveActive
				activeColor: Theme.accentGreen
				hasDetails: false
				onIconClicked: win.togglePowerSave()
				onBodyClicked: win.togglePowerSave()
			}

			SamsungTile {
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

			SamsungTile {
				itemRow: win.rowStayAwakeDnd
				itemCol: 0
				hotkey: "A"
				icon: "coffee"
				title: "Keep awake"
				subtitle: ""
				active: SystemStatus.awakeActive
				hasDetails: false
				onIconClicked: win.toggleAwake()
				onBodyClicked: win.toggleAwake()
			}

			SamsungTile {
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

	PowerSubView {
		id: powerSubView
		anchors.fill: parent
		visible: win.subView === "power"
		enabled: visible
		focus: visible
		onBackRequested: win.backToMain()
	}
}
