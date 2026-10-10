import ".."
import "../widgets"
import "./quicksettings"
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

SideDrawer {
	id: win

	shown: QuickSettings.panelOpen
	instantHide: QuickSettings.instantHide
	dismissOnEsc: QuickSettings.subView === "main"
	cardWidth: 520
	fromLeft: true
	readonly property int mainContentHeight: Math.min((contentCol.implicitHeight > 0 ? contentCol.implicitHeight : 430) + Theme.paddingCard * 2, win.height - Theme.notifTopMargin - 20)
	readonly property int currentSubViewHeight: {
		if (QuickSettings.subView === "wifi")
			return wifiSubView.preferredHeight + Theme.paddingCard * 2;
		if (QuickSettings.subView === "bluetooth")
			return btSubView.preferredHeight + Theme.paddingCard * 2;
		if (QuickSettings.subView === "capture")
			return captureSubView.preferredHeight + Theme.paddingCard * 2;
		return 540;
	}
	readonly property int subViewHeight: Math.min(currentSubViewHeight, Math.min(680, win.height - Theme.notifTopMargin - 20))
	cardHeight: QuickSettings.subView === "main" ? mainContentHeight : subViewHeight

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
		switch (QuickSettings.subView) {
		case "main": contentCol.forceActiveFocus(); break;
		case "wifi": wifiSubView.forceActiveFocus(); break;
		case "bluetooth": btSubView.forceActiveFocus(); break;
		case "capture": captureSubView.forceActiveFocus(); break;
		}
	}

	function backToMain(): void {
		QuickSettings.subView = "main";
		contentCol.forceActiveFocus();
	}

	function togglePowerSave(): void {
		Quickshell.execDetached(["sh", "-c", "~/.local/bin/power-save"]);
		markerRefresh.restart();
	}

	function toggleAwake(): void {
		Quickshell.execDetached(["sh", "-c", "~/.local/bin/awake-toggle"]);
		markerRefresh.restart();
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
			if (c === 0)
				viaIcon ? toggleWifiRadio() : QuickSettings.openWifi();
			else
				viaIcon ? toggleBtRadio() : QuickSettings.openBluetooth();
		} else if (r === rowBatteryCapture) {
			if (c === 0)
				togglePowerSave();
			else
				QuickSettings.openCapture();
		} else if (r === rowStayAwakeDnd) {
			if (c === 0)
				toggleAwake();
			else
				Notifications.toggleDnd();
		}
	}

	onOpened: {
		Notifications.closeCenter();
		Weather.close();
		refreshVolume();
		refreshBrightness();
		if (QuickSettings.subView === "main")
			select(0, 0);
		focusSubView();
	}
	onDismissed: QuickSettings.close()
	onDrawerClosed: {
		QuickSettings.instantHide = false;
		QuickSettings.subView = "main";
	}

	Connections {
		target: QuickSettings
		function onSubViewChanged() {
			win.focusSubView();
		}
	}

	property real volPct: 20
	property bool volMuted: false
	property bool volReady: false
	property int volMax: 100
	property real volShown: 20
	readonly property string volIcon: win.volMuted ? "󰝟" : (win.volPct <= 1 ? "󰕿" : (win.volPct <= 50 ? "󰖀" : "󰕾"))

	function refreshVolume(): void {
		if (!volQuery.running)
			volQuery.running = true;
	}

	function playVolumeSound(): void {
		if (!win.volMuted)
			Quickshell.execDetached(["canberra-gtk-play", "-i", "audio-volume-change"]);
	}

	function commitVolume(): void {
		volSet.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", String(Math.round(win.volShown)) + "%"];
		volSet.running = true;
		win.playVolumeSound();
	}

	function toggleMute(): void {
		if (!volMuteProc.running)
			volMuteProc.running = true;
	}

	Process {
		id: volQuery
		command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
		stdout: StdioCollector {
			onStreamFinished: {
				var line = String(this.text || "");
				var m = line.match(/Volume:\s+([0-9.]+)/);
				if (m) {
					var pct = Math.round(parseFloat(m[1]) * 100);
					win.volPct = Math.max(0, Math.min(win.volMax, pct));
					win.volMuted = line.indexOf("MUTED") !== -1;
					win.volReady = true;
					if (!volRow.slider.pressed)
						win.volShown = Math.max(0, Math.min(win.volMax, pct));
				}
			}
		}
	}

	Process {
		id: volSet
		onExited: win.refreshVolume()
	}

	Process {
		id: volMuteProc
		command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
		onExited: win.refreshVolume()
	}

	Timer {
		id: volSettle
		interval: 80
		onTriggered: win.commitVolume()
	}

	property int brightness: 50
	property bool brightnessReady: false

	function refreshBrightness(): void {
		if (!briQuery.running)
			briQuery.running = true;
	}

	function commitBrightness(): void {
		briSet.command = ["brightnessctl", "-c", "backlight", "set", String(win.brightness) + "%", "-q"];
		briSet.running = true;
	}

	Process {
		id: briQuery
		command: ["sh", "-c", "brightnessctl -c backlight -m 2>/dev/null | head -n 1 | cut -d, -f4 | tr -dc '0-9'"]
		stdout: StdioCollector {
			onStreamFinished: {
				var v = parseInt(String(this.text || "").trim());
				if (!isNaN(v) && !briRow.slider.pressed) {
					win.brightness = Math.max(0, Math.min(100, v));
					win.brightnessReady = true;
				}
			}
		}
	}

	Process {
		id: briSet
		onExited: win.refreshBrightness()
	}

	Timer {
		id: briSettle
		interval: 60
		onTriggered: win.commitBrightness()
	}

	readonly property var wifiDevice: {
		var vals = Networking.devices.values;
		for (var i = 0; i < vals.length; i++)
			if (vals[i].type === DeviceType.Wifi)
				return vals[i];
		return null;
	}
	readonly property bool wifiUp: win.wifiDevice?.connected ?? false
	readonly property string activeSsid: {
		var d = win.wifiDevice;
		if (!d || !d.networks || !d.networks.values)
			return "";
		var vals = d.networks.values;
		for (var i = 0; i < vals.length; i++)
			if (vals[i] && vals[i].connected)
				return vals[i].name || "";
		return "";
	}
	readonly property string wifiSubtitle: {
		if (!Networking.wifiHardwareEnabled)
			return "Blocked";
		if (!Networking.wifiEnabled)
			return "Off";
		return win.activeSsid !== "" ? win.activeSsid : (win.wifiUp ? "On" : "No connection");
	}

	readonly property var btAdapter: Bluetooth.defaultAdapter
	readonly property bool btEnabled: win.btAdapter?.enabled ?? false
	readonly property int btConnected: {
		var a = win.btAdapter;
		if (!a || !a.devices || !a.devices.values)
			return 0;
		var n = 0;
		var vals = a.devices.values || [];
		for (var i = 0; i < vals.length; i++)
			if (vals[i].connected)
				n++;
		return n;
	}
	readonly property string btSubtitle: {
		if (!win.btAdapter)
			return "No adapter";
		if (win.btConnected > 1)
			return win.btConnected + " connected";
		if (win.btConnected === 1) {
			var vals = (win.btAdapter.devices && win.btAdapter.devices.values) || [];
			for (var i = 0; i < vals.length; i++) {
				if (vals[i].connected)
					return vals[i].name || vals[i].deviceName || "Connected";
			}
			return "Connected";
		}
		return win.btEnabled ? "On" : "Off";
	}

	Timer {
		id: pollTimer
		interval: 3000
		running: win.shown
		repeat: true
		triggeredOnStart: true
		onTriggered: {
			SystemStatus.refresh();
			win.refreshVolume();
			if (!briRow.slider.pressed)
				win.refreshBrightness();
		}
	}

	Timer {
		id: markerRefresh
		interval: 100
		onTriggered: SystemStatus.refresh()
	}

	Connections {
		target: QuickSettings
		function onRefreshRequested(): void {
			SystemStatus.refresh();
			win.refreshVolume();
			if (!briRow.slider.pressed)
				win.refreshBrightness();
		}
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

		property bool badgeHovered: (stile.hasDetails && stile.hasToggleBadge)
			? (tileArea.containsMouse && stile.isOverBadge(tileArea.mouseX, tileArea.mouseY))
			: false
		property bool bodyHovered: (stile.hasDetails && stile.hasToggleBadge)
			? (tileArea.containsMouse && !stile.isOverBadge(tileArea.mouseX, tileArea.mouseY))
			: tileArea.containsMouse

		signal iconClicked()
		signal bodyClicked()

		Layout.fillWidth: true
		Layout.preferredHeight: 76
		radius: Theme.roundingElement

		color: (stile.active
			? Theme.alpha(stile.activeColor, stile.bodyHovered ? 0.18 : 0.10)
			: (stile.bodyHovered ? Theme.bgHover : Theme.bgMain))

		border.color: (stile.active
			? (stile.bodyHovered ? stile.activeColor : Theme.alpha(stile.activeColor, 0.40))
			: (stile.bodyHovered ? Theme.textDim : Theme.border))
		border.width: 1

		Behavior on color { ColorAnimation { duration: 120 } }
		Behavior on border.color { ColorAnimation { duration: 120 } }

		SelectionHighlight {
			selected: stile.isSelected
			color: stile.active ? Theme.alpha(stile.activeColor, 0.15) : Theme.selectionBg
			border.color: stile.active ? stile.activeColor : Theme.selectionBorder
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
						: (stile.badgeHovered ? Theme.bgHover : Theme.bgCard))
					: "transparent"
				border.color: (stile.hasDetails && stile.hasToggleBadge)
					? (stile.active
						? (stile.badgeHovered ? Qt.lighter(stile.activeColor, 1.30) : "transparent")
						: (stile.badgeHovered ? Theme.textDim : Theme.border))
					: "transparent"
				border.width: (stile.hasDetails && stile.hasToggleBadge) ? 1 : 0

				Behavior on color { ColorAnimation { duration: 140 } }
				Behavior on border.color { ColorAnimation { duration: 120 } }

				Text {
					anchors.centerIn: parent
					text: stile.icon
					font.family: Theme.fontFamily
					font.pixelSize: 22
					font.bold: true
					color: (stile.hasDetails && stile.hasToggleBadge)
						? (stile.active ? Theme.bgMain : (stile.badgeHovered ? Theme.textMain : Theme.textDim))
						: (stile.active ? stile.activeColor : (stile.bodyHovered ? Theme.textMain : Theme.textDim))
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

		Text {
			visible: stile.hotkey !== ""
			anchors.right: parent.right
			anchors.bottom: parent.bottom
			anchors.rightMargin: 10
			anchors.bottomMargin: 6
			text: stile.hotkey
			font.family: Theme.fontMono
			font.pixelSize: 10
			font.bold: true
			color: stile.isSelected ? Theme.accentBlue : Theme.textDim
			opacity: stile.isSelected ? 0.9 : 0.4
			z: 2
		}
	}

	ColumnLayout {
		id: contentCol
		anchors.fill: parent
		spacing: 10
		focus: true
		visible: QuickSettings.subView === "main"
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
					win.volShown = Math.max(0, win.volShown - 5);
					win.commitVolume();
				} else if (win.navRow === win.rowBrightness && win.brightnessReady) {
					win.brightness = Math.max(0, win.brightness - 5);
					win.commitBrightness();
				} else if (win.navRow >= win.rowTilesStart && win.navRow <= win.maxRow) {
					win.navCol = 0;
				}
				event.accepted = true;
			} else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
				if (win.navRow === win.rowVolume) {
					win.volShown = Math.min(win.volMax, win.volShown + 5);
					win.commitVolume();
				} else if (win.navRow === win.rowBrightness && win.brightnessReady) {
					win.brightness = Math.min(100, win.brightness + 5);
					win.commitBrightness();
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
				QuickSettings.openCapture();
				win.select(win.rowBatteryCapture, 1);
				event.accepted = true;
			} else if (event.key === Qt.Key_W) {
				if (event.modifiers & Qt.ShiftModifier) {
					win.toggleWifiRadio();
					win.select(win.rowWifiBt, 0);
				} else {
					QuickSettings.openWifi();
				}
				event.accepted = true;
			} else if (event.key === Qt.Key_B) {
				if (event.modifiers & Qt.ShiftModifier) {
					win.toggleBtRadio();
					win.select(win.rowWifiBt, 1);
				} else {
					QuickSettings.openBluetooth();
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
				Notifications.toggleDnd();
				win.select(win.rowStayAwakeDnd, 1);
				event.accepted = true;
			} else if (event.key === Qt.Key_M) {
				win.toggleMute();
				win.select(win.rowVolume, 0);
				event.accepted = true;
			} else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
				QuickSettings.close();
				event.accepted = true;
			}
		}

		RowLayout {
			Layout.fillWidth: true
			Layout.preferredHeight: 32
			spacing: 10

			Text {
				Layout.fillWidth: true
				text: "Quick actions"
				font.family: Theme.fontFamily
				font.pixelSize: Theme.fontSize + 1
				font.bold: true
				color: Theme.textMain
			}

			CloseButton {
				onClicked: QuickSettings.close()
			}
		}

		SliderRow {
			id: volRow
			current: win.isCurrent(win.rowVolume)
			icon: win.volIcon
			label: win.volReady ? (win.volMuted ? "Muted" : Math.round(volRow.slider.pressed ? win.volShown : win.volPct) + "%") : "…"
			ready: win.volReady
			muted: win.volMuted
			value: win.volShown
			maxValue: win.volMax
			iconInteractive: true
			onSelectRequested: win.select(win.rowVolume, 0)
			onIconClicked: win.toggleMute()
			onScrubbed: v => {
				win.volShown = Math.round(v);
				if (volSettle.running)
					volSettle.restart();
				else {
					win.commitVolume();
					volSettle.restart();
				}
			}
		}

		SliderRow {
			id: briRow
			visible: win.brightnessReady
			current: win.isCurrent(win.rowBrightness)
			icon: "󰃟"
			label: win.brightnessReady ? win.brightness + "%" : "…"
			ready: win.brightnessReady
			value: win.brightness
			onSelectRequested: win.select(win.rowBrightness, 0)
			onScrubbed: v => {
				win.brightness = Math.round(v);
				if (briSettle.running)
					briSettle.restart();
				else {
					win.commitBrightness();
					briSettle.restart();
				}
			}
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
				icon: win.wifiUp ? "󰖩" : "󰖪"
				title: "Wi-Fi"
				subtitle: win.wifiSubtitle
				active: Networking.wifiEnabled
				hasDetails: true
				onIconClicked: win.toggleWifiRadio()
				onBodyClicked: QuickSettings.openWifi()
			}

			SamsungTile {
				itemRow: win.rowWifiBt
				itemCol: 1
				hotkey: "B"
				icon: !win.btEnabled ? "󰂲" : (win.btConnected > 0 ? "󰂱" : "󰂯")
				title: "Bluetooth"
				subtitle: win.btSubtitle
				active: win.btEnabled
				hasDetails: true
				onIconClicked: win.toggleBtRadio()
				onBodyClicked: QuickSettings.openBluetooth()
			}

			SamsungTile {
				itemRow: win.rowBatteryCapture
				itemCol: 0
				hotkey: "S"
				icon: "󰌪"
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
				icon: SystemStatus.recording ? "󰻃" : "󰹑"
				title: "Capture"
				subtitle: SystemStatus.recording ? "Recording" : ""
				active: SystemStatus.recording
				activeColor: Theme.critical
				hasDetails: true
				hasToggleBadge: false
				onIconClicked: QuickSettings.openCapture()
				onBodyClicked: QuickSettings.openCapture()
			}

			SamsungTile {
				itemRow: win.rowStayAwakeDnd
				itemCol: 0
				hotkey: "A"
				icon: "󰖦"
				title: "Awake"
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
				icon: Notifications.dnd ? "󰂛" : "󰂜"
				title: "Do not disturb"
				subtitle: ""
				active: Notifications.dnd
				activeColor: Theme.warning
				hasDetails: false
				onIconClicked: Notifications.toggleDnd()
				onBodyClicked: Notifications.toggleDnd()
			}
		}
	}

	WifiSubView {
		id: wifiSubView
		anchors.fill: parent
		visible: QuickSettings.subView === "wifi"
		enabled: visible
		focus: visible
		onBackRequested: win.backToMain()
		onCloseRequested: QuickSettings.close()
	}

	BluetoothSubView {
		id: btSubView
		anchors.fill: parent
		visible: QuickSettings.subView === "bluetooth"
		enabled: visible
		focus: visible
		onBackRequested: win.backToMain()
		onCloseRequested: QuickSettings.close()
	}

	CaptureSubView {
		id: captureSubView
		anchors.fill: parent
		visible: QuickSettings.subView === "capture"
		enabled: visible
		focus: visible
		onBackRequested: win.backToMain()
		onCloseRequested: QuickSettings.close()
	}
}
