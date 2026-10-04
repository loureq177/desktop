// Quick settings panel: OneUI/GNOME-style slide-in drawer from top-right.
// Pill sliders on top, toggle tiles below (Wi-Fi, Bluetooth,
// battery saver, DND, awake, night light) and a power button.
// Toggle via IPC: `qs ipc call quicksettings toggle` (SUPER + A).
// ESC or clicking outside dismisses the panel.
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

	// ─── 2D Navigation state ─────────────────────────────────────────
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

	onOpened: {
		Notifications.closeCenter();
		Weather.close();
		refreshVolume();
		refreshBrightness();
		if (QuickSettings.subView === "main") {
			select(0, 0);
			contentCol.forceActiveFocus();
		} else if (QuickSettings.subView === "wifi") {
			wifiSubView.forceActiveFocus();
		} else if (QuickSettings.subView === "bluetooth") {
			btSubView.forceActiveFocus();
		} else if (QuickSettings.subView === "capture") {
			captureSubView.forceActiveFocus();
		}
	}
	onDismissed: QuickSettings.close()
	onDrawerClosed: {
		QuickSettings.instantHide = false;
		QuickSettings.subView = "main";
	}

	Connections {
		target: QuickSettings
		function onSubViewChanged() {
			if (QuickSettings.subView === "main") {
				contentCol.forceActiveFocus();
			} else if (QuickSettings.subView === "wifi") {
				wifiSubView.forceActiveFocus();
			} else if (QuickSettings.subView === "bluetooth") {
				btSubView.forceActiveFocus();
			} else if (QuickSettings.subView === "capture") {
				captureSubView.forceActiveFocus();
			}
		}
	}

	// ─── Backend state ──────────────────────────────────────────────

	// Audio output via wpctl (polled): the Pipewire QML node for the
	// default sink stays unbound (writes fail with "not bound"), so the
	// panel shells out exactly like volume instead.
	property real volPct: 20
	property bool volMuted: false
	property bool volReady: false
	// Volume capped at 100% (`-l 1.0`); the slider, OSD and
	// PipeWire stay in the same range instead of boosting to 150%.
	property int volMax: 100
	// Thumb position: follows the finger while dragging, the backend
	// readout otherwise (avoids snap-back between polls).
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
					if (!volPill.pressed)
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

	// Backlight: polled via brightnessctl, writes debounced while dragging.
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
				if (!isNaN(v) && !briPill.pressed) {
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

	// Wi-Fi: radio state from NetworkManager, SSID from the active network.
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

	// Bluetooth: adapter switch + connected-device count.
	readonly property var btAdapter: Bluetooth.defaultAdapter
	readonly property bool btEnabled: win.btAdapter?.enabled ?? false
	readonly property int btConnected: {
		var a = win.btAdapter;
		if (!a)
			return 0;
		var n = 0;
		var vals = a.devices.values;
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
			var vals = win.btAdapter.devices.values;
			for (var i = 0; i < vals.length; i++) {
				if (vals[i].connected)
					return vals[i].name || vals[i].deviceName || "Connected";
			}
			return "Connected";
		}
		return win.btEnabled ? "On" : "Off";
	}

	// Backlight & volume re-read while the panel is open.
	Timer {
		id: pollTimer
		interval: 3000
		running: win.shown
		repeat: true
		triggeredOnStart: true
		onTriggered: {
			SystemStatus.refresh();
			win.refreshVolume();
			if (!briPill.pressed)
				win.refreshBrightness();
		}
	}

	// Optimistic refresh after marker-file toggles (scripts are async).
	Timer {
		id: markerRefresh
		interval: 100
		onTriggered: SystemStatus.refresh()
	}

	// External writers call `qs ipc call quicksettings refresh`
	Connections {
		target: QuickSettings
		function onRefreshRequested(): void {
			SystemStatus.refresh();
			win.refreshVolume();
			if (!briPill.pressed)
				win.refreshBrightness();
		}
	}

	// ─── Reusable tiles ─────────────────────────────────────────────

	// 2-column tile: tactile, rounded icon badge, large bold title,
	// subtitle, hotkey, and subtle detail chevron (›).
	// Icon badge toggles; body opens details when hasDetails.
	// Vim keys: h/j/k/l 2D navigation, Enter/Space/O opens details,
	// W/B open wifi/bt (Shift+W/B toggles radio).
	component SamsungTile: Rectangle {
		id: stile

		property string icon: ""
		property string title: ""
		property string subtitle: ""
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
			? (stile.bodyHovered
				? Qt.rgba(stile.activeColor.r, stile.activeColor.g, stile.activeColor.b, 0.18)
				: Qt.rgba(stile.activeColor.r, stile.activeColor.g, stile.activeColor.b, 0.10))
			: (stile.bodyHovered ? Theme.bgHover : Theme.bgMain))

		border.color: (stile.active
			? (stile.bodyHovered ? stile.activeColor : Qt.rgba(stile.activeColor.r, stile.activeColor.g, stile.activeColor.b, 0.40))
			: (stile.bodyHovered ? Theme.textDim : Theme.border))
		border.width: 1

		Behavior on color { ColorAnimation { duration: 120 } }
		Behavior on border.color { ColorAnimation { duration: 120 } }

		Rectangle {
			anchors.fill: parent
			radius: stile.radius
			color: stile.active
				? Qt.rgba(stile.activeColor.r, stile.activeColor.g, stile.activeColor.b, 0.15)
				: Theme.selectionBg
			border.color: stile.active
				? stile.activeColor
				: Theme.selectionBorder
			border.width: 1
			opacity: stile.isSelected ? 1.0 : 0.0
			visible: opacity > 0.0
			z: 0

			Behavior on opacity {
				NumberAnimation {
					duration: 140
					easing.type: Easing.OutCubic
				}
			}
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
	}

	// OneUI-style pill slider: thick rounded track, fill = value, no
	// detached handle. Value flows one way (parent -> pill); user drags
	// emit scrubbed() and the parent writes back + debounces the commit.
	// This avoids the QtQuick.Controls binding-break where a drag severs
	// `value:` and the backend poll stops moving the thumb.
	component PillSlider: Item {
		id: pill

		property real value: 0
		property real maxValue: 100
		property bool ready: false
		property bool muted: false
		property color fillColor: Theme.accentBlue
		property alias pressed: slideArea.pressed
		property alias hovered: slideArea.containsMouse
		signal scrubbed(real v)

		Layout.fillWidth: true
		Layout.preferredHeight: 48
		Layout.alignment: Qt.AlignVCenter
		enabled: pill.ready
		opacity: enabled ? 1.0 : 0.4

		function ratioToValue(rx: real): real {
			return Math.max(0, Math.min(pill.maxValue, Math.round(rx / track.width * pill.maxValue)));
		}

		Rectangle {
			id: track
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			height: pill.pressed ? 22 : 20
			radius: Theme.roundingElement
			color: Theme.bgHover
			border.color: slideArea.containsMouse || pill.pressed ? Theme.textDim : Theme.border
			border.width: 1
			clip: true

			Behavior on height {
				NumberAnimation { duration: 100 }
			}
			Behavior on border.color {
				ColorAnimation { duration: 120 }
			}

			Rectangle {
				anchors.left: parent.left
				anchors.top: parent.top
				anchors.bottom: parent.bottom
				width: parent.width * Math.max(0, Math.min(pill.maxValue, pill.value)) / pill.maxValue
				radius: parent.radius
				color: pill.muted ? Theme.textDim : pill.fillColor

				Behavior on color {
					ColorAnimation { duration: 120 }
				}
			}

			MouseArea {
				id: slideArea
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				preventStealing: true
				onPressed: mouse => pill.scrubbed(pill.ratioToValue(mouse.x))
				onPositionChanged: mouse => {
					if (pressed)
						pill.scrubbed(pill.ratioToValue(mouse.x));
				}
			}
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
				if (win.navRow === win.rowVolume) {
					win.toggleMute();
				} else if (win.navRow === win.rowWifiBt && win.navCol === 0) {
					QuickSettings.openWifi();
				} else if (win.navRow === win.rowWifiBt && win.navCol === 1) {
					QuickSettings.openBluetooth();
				} else if (win.navRow === win.rowBatteryCapture && win.navCol === 0) {
					Quickshell.execDetached(["sh", "-c", "~/.local/bin/power-save"]);
					markerRefresh.restart();
				} else if (win.navRow === win.rowBatteryCapture && win.navCol === 1) {
					QuickSettings.openCapture();
				} else if (win.navRow === win.rowStayAwakeDnd && win.navCol === 0) {
					Quickshell.execDetached(["sh", "-c", "~/.local/bin/awake-toggle"]);
					markerRefresh.restart();
				} else if (win.navRow === win.rowStayAwakeDnd && win.navCol === 1) {
					Notifications.toggleDnd();
				}
				event.accepted = true;
			} else if (event.key === Qt.Key_Space) {
				if (win.navRow === win.rowWifiBt && win.navCol === 0) {
					QuickSettings.openWifi();
				} else if (win.navRow === win.rowWifiBt && win.navCol === 1) {
					QuickSettings.openBluetooth();
				} else if (win.navRow === win.rowBatteryCapture && win.navCol === 0) {
					Quickshell.execDetached(["sh", "-c", "~/.local/bin/power-save"]);
					markerRefresh.restart();
				} else if (win.navRow === win.rowBatteryCapture && win.navCol === 1) {
					QuickSettings.openCapture();
				} else if (win.navRow === win.rowVolume) {
					win.toggleMute();
				} else if (win.navRow === win.rowStayAwakeDnd && win.navCol === 0) {
					Quickshell.execDetached(["sh", "-c", "~/.local/bin/awake-toggle"]);
					markerRefresh.restart();
				} else if (win.navRow === win.rowStayAwakeDnd && win.navCol === 1) {
					Notifications.toggleDnd();
				}
				event.accepted = true;
			} else if (event.key === Qt.Key_O) {
				if (win.navRow === win.rowWifiBt && win.navCol === 0) {
					QuickSettings.openWifi();
				} else if (win.navRow === win.rowWifiBt && win.navCol === 1) {
					QuickSettings.openBluetooth();
				} else if (win.navRow === win.rowBatteryCapture && win.navCol === 1) {
					QuickSettings.openCapture();
				}
				event.accepted = true;
			} else if (event.key === Qt.Key_C) {
				QuickSettings.openCapture();
				win.select(win.rowBatteryCapture, 1);
				event.accepted = true;
			} else if (event.key === Qt.Key_W) {
				if (event.modifiers & Qt.ShiftModifier) {
					if (Networking.wifiHardwareEnabled)
						Networking.wifiEnabled = !Networking.wifiEnabled;
					win.select(win.rowWifiBt, 0);
				} else {
					QuickSettings.openWifi();
				}
				event.accepted = true;
			} else if (event.key === Qt.Key_B) {
				if (event.modifiers & Qt.ShiftModifier) {
					if (win.btAdapter)
						win.btAdapter.enabled = !win.btAdapter.enabled;
					win.select(win.rowWifiBt, 1);
				} else {
					QuickSettings.openBluetooth();
				}
				event.accepted = true;
			} else if (event.key === Qt.Key_S) {
				Quickshell.execDetached(["sh", "-c", "~/.local/bin/power-save"]);
				markerRefresh.restart();
				win.select(win.rowBatteryCapture, 0);
				event.accepted = true;
			} else if (event.key === Qt.Key_A) {
				Quickshell.execDetached(["sh", "-c", "~/.local/bin/awake-toggle"]);
				markerRefresh.restart();
				win.select(win.rowStayAwakeDnd, 0);
				event.accepted = true;
			} else if (event.key === Qt.Key_D) {
				Notifications.toggleDnd();
				win.select(win.rowStayAwakeDnd, 1);
				event.accepted = true;
			} else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
				QuickSettings.close();
				event.accepted = true;
			}
		}

		// ─── Header ─────────────────────────────────────────
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

			CloseButton {
				onClicked: QuickSettings.close()
			}
		}

		// ─── Volume slider ──────────────────────────────────
		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 48
			radius: Theme.roundingElement
			color: "transparent"
			border.width: 0

			Rectangle {
				anchors.fill: parent
				radius: parent.radius
				color: Theme.selectionBg
				border.color: Theme.selectionBorder
				border.width: 1
				opacity: win.isCurrent(win.rowVolume) ? 1.0 : 0.0
				visible: opacity > 0.0
				z: 0

				Behavior on opacity {
					NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
				}
			}

			MouseArea {
				anchors.fill: parent
				z: 0
				onClicked: win.select(win.rowVolume, 0)
			}

			RowLayout {
				anchors.fill: parent
				anchors.leftMargin: 4
				anchors.rightMargin: 8
				spacing: 10
				z: 1

				Rectangle {
					Layout.preferredWidth: 40
					Layout.preferredHeight: 40
					radius: Theme.roundingSubtle
					color: volMuteArea.containsMouse ? Theme.bgHover : "transparent"
					border.color: volMuteArea.containsMouse ? Theme.textDim : Theme.border
					border.width: 1
					opacity: win.volReady ? 1.0 : 0.4

					Text {
						anchors.centerIn: parent
						text: win.volIcon
						font.family: Theme.fontFamily
						font.pixelSize: 22
						font.bold: true
						color: win.volMuted ? Theme.textDim : Theme.accentBlue
					}

					MouseArea {
						id: volMuteArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: win.toggleMute()
					}
				}

				PillSlider {
					id: volPill
					value: win.volShown
					maxValue: win.volMax
					ready: win.volReady
					muted: win.volMuted
					fillColor: Theme.accentBlue
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

				Text {
					Layout.preferredWidth: 56
					horizontalAlignment: Text.AlignRight
					text: win.volReady ? (win.volMuted ? "Muted" : Math.round(volPill.pressed ? win.volShown : win.volPct) + "%") : "…"
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeSmall + 1
					font.bold: true
					color: Theme.textMain
				}
			}
		}

		// ─── Brightness slider ──────────────────────────────
		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 48
			radius: Theme.roundingElement
			visible: win.brightnessReady
			color: "transparent"
			border.width: 0

			Rectangle {
				anchors.fill: parent
				radius: parent.radius
				color: Theme.selectionBg
				border.color: Theme.selectionBorder
				border.width: 1
				opacity: win.isCurrent(win.rowBrightness) ? 1.0 : 0.0
				visible: opacity > 0.0
				z: 0

				Behavior on opacity {
					NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
				}
			}

			MouseArea {
				anchors.fill: parent
				z: 0
				onClicked: win.select(win.rowBrightness, 0)
			}

			RowLayout {
				anchors.fill: parent
				anchors.leftMargin: 4
				anchors.rightMargin: 8
				spacing: 10
				z: 1

				Rectangle {
					Layout.preferredWidth: 40
					Layout.preferredHeight: 40
					radius: Theme.roundingSubtle
					color: "transparent"
					border.color: Theme.border
					border.width: 1
					opacity: win.brightnessReady ? 1.0 : 0.4

					Text {
						anchors.centerIn: parent
						text: "󰃟"
						font.family: Theme.fontFamily
						font.pixelSize: 22
						font.bold: true
						color: Theme.accentBlue
					}
				}

				PillSlider {
					id: briPill
					value: win.brightness
					ready: win.brightnessReady
					fillColor: Theme.accentBlue
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

				Text {
					Layout.preferredWidth: 56
					horizontalAlignment: Text.AlignRight
					text: win.brightnessReady ? win.brightness + "%" : "…"
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeSmall + 1
					font.bold: true
					color: Theme.textMain
				}
			}
		}

		// ─── 2-Column Toggle tiles ───────────────────────────
		GridLayout {
			Layout.fillWidth: true
			columns: 2
			columnSpacing: 8
			rowSpacing: 8

			SamsungTile {
				itemRow: win.rowWifiBt
				itemCol: 0
				icon: win.wifiUp ? "󰖩" : "󰖪"
				title: "Wi-Fi"
				subtitle: win.wifiSubtitle
				active: Networking.wifiEnabled
				hasDetails: true
				onIconClicked: {
					if (Networking.wifiHardwareEnabled)
						Networking.wifiEnabled = !Networking.wifiEnabled;
				}
				onBodyClicked: QuickSettings.openWifi()
			}

			SamsungTile {
				itemRow: win.rowWifiBt
				itemCol: 1
				icon: !win.btEnabled ? "󰂲" : (win.btConnected > 0 ? "󰂱" : "󰂯")
				title: "Bluetooth"
				subtitle: win.btSubtitle
				active: win.btEnabled
				hasDetails: true
				onIconClicked: {
					if (win.btAdapter)
						win.btAdapter.enabled = !win.btAdapter.enabled;
				}
				onBodyClicked: QuickSettings.openBluetooth()
			}

			SamsungTile {
				itemRow: win.rowBatteryCapture
				itemCol: 0
				icon: "󰌪"
				title: "Battery saver"
				subtitle: SystemStatus.powerSaveActive ? "60 Hz" : ""
				active: SystemStatus.powerSaveActive
				activeColor: Theme.accentGreen
				hasDetails: false
				onIconClicked: {
					Quickshell.execDetached(["sh", "-c", "~/.local/bin/power-save"]);
					markerRefresh.restart();
				}
				onBodyClicked: {
					Quickshell.execDetached(["sh", "-c", "~/.local/bin/power-save"]);
					markerRefresh.restart();
				}
			}

			SamsungTile {
				itemRow: win.rowBatteryCapture
				itemCol: 1
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
				icon: "󰖦"
				title: "Awake"
				subtitle: ""
				active: SystemStatus.awakeActive
				hasDetails: false
				onIconClicked: {
					Quickshell.execDetached(["sh", "-c", "~/.local/bin/awake-toggle"]);
					markerRefresh.restart();
				}
				onBodyClicked: {
					Quickshell.execDetached(["sh", "-c", "~/.local/bin/awake-toggle"]);
					markerRefresh.restart();
				}
			}

			SamsungTile {
				itemRow: win.rowStayAwakeDnd
				itemCol: 1
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
		onBackRequested: {
			QuickSettings.subView = "main";
			contentCol.forceActiveFocus();
		}
		onCloseRequested: QuickSettings.close()
	}

	BluetoothSubView {
		id: btSubView
		anchors.fill: parent
		visible: QuickSettings.subView === "bluetooth"
		enabled: visible
		focus: visible
		onBackRequested: {
			QuickSettings.subView = "main";
			contentCol.forceActiveFocus();
		}
		onCloseRequested: QuickSettings.close()
	}

	CaptureSubView {
		id: captureSubView
		anchors.fill: parent
		visible: QuickSettings.subView === "capture"
		enabled: visible
		focus: visible
		onBackRequested: {
			QuickSettings.subView = "main";
			contentCol.forceActiveFocus();
		}
		onCloseRequested: QuickSettings.close()
	}
}
