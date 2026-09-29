// Quick settings panel: OneUI/GNOME-style slide-in drawer from top-right.
// Pill sliders on top, toggle tiles below (Wi-Fi, Bluetooth,
// battery saver, DND, stay-awake, night light) and a power button.
// Toggle via IPC: `qs ipc call quicksettings toggle` (SUPER + A).
// ESC or clicking outside dismisses the panel.
import ".."
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
	cardHeight: Math.min(contentCol.implicitHeight + Theme.paddingCard * 2, win.height - Theme.notifTopMargin - 20)
	onOpened: {
		Notifications.closeCenter();
		refreshVolume();
		refreshBrightness();
	}
	onDismissed: QuickSettings.close()

	// ─── Backend state ──────────────────────────────────────────────

	// Audio output via wpctl (polled): the Pipewire QML node for the
	// default sink stays unbound (writes fail with "not bound"), so the
	// panel shells out exactly like volume.sh instead.
	property real volPct: 20
	property bool volMuted: false
	property bool volReady: false
	// wpctl allows boosting to 150% (`-l 1.5`); the slider spans the same
	// range as the OSD instead of clipping at 100.
	property int volMax: 150
	// Thumb position: follows the finger while dragging, the backend
	// readout otherwise (avoids snap-back between polls).
	property real volShown: 20
	readonly property string volIcon: win.volMuted ? "󰝟" : (win.volPct <= 1 ? "󰕿" : (win.volPct <= 50 ? "󰖀" : "󰕾"))

	function refreshVolume(): void {
		if (!volQuery.running)
			volQuery.running = true;
	}

	function commitVolume(): void {
		volSet.command = ["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", String(Math.round(win.volShown)) + "%"];
		volSet.running = true;
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
		if (win.btConnected === 1)
			return "Connected";
		return win.btEnabled ? "On" : "Off";
	}

	// Caffeine / power-save toggles leave marker files in XDG_RUNTIME_DIR;
	// their existence is the state (loadFailed = absent = off).
	FileView {
		id: caffeineMarker
		path: Quickshell.env("XDG_RUNTIME_DIR") + "/caffeine_inhibit.pid"
		printErrors: false
	}
	FileView {
		id: powerSaveMarker
		path: Quickshell.env("XDG_RUNTIME_DIR") + "/powersave_mode"
		printErrors: false
	}

	// Night light (hyprsunset): no query API, so the toggle owns the state.
	// Initial guess follows the timed profiles in hyprsunset.conf (warm
	// 20:00–06:00); a manual toggle overrides until the next profile switch.
	property bool nightLight: {
		var h = new Date().getHours();
		return h >= 20 || h < 6;
	}

	function toggleNightLight(): void {
		win.nightLight = !win.nightLight;
		if (win.nightLight)
			Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", "4500"]);
		else
			Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"]);
	}

	function openSpecial(name: string): void {
		QuickSettings.close();
		Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.workspace.toggle_special('" + name + "')"]);
	}

	// Marker files + backlight re-read while the panel is open.
	Timer {
		id: pollTimer
		interval: 3000
		running: win.shown
		repeat: true
		triggeredOnStart: true
		onTriggered: {
			caffeineMarker.reload();
			powerSaveMarker.reload();
			win.refreshVolume();
			if (!briPill.pressed)
				win.refreshBrightness();
		}
	}

	// Optimistic refresh after marker-file toggles (scripts are async).
	Timer {
		id: markerRefresh
		interval: 600
		onTriggered: {
			caffeineMarker.reload();
			powerSaveMarker.reload();
		}
	}

	// External writers (volume.sh, brightness.sh, power-save.sh) call
	// `qs ipc call quicksettings refresh` after changing state, so an open
	// panel follows hardware keys instead of lagging one poll behind.
	Connections {
		target: QuickSettings
		function onRefreshRequested(): void {
			caffeineMarker.reload();
			powerSaveMarker.reload();
			win.refreshVolume();
			if (!briPill.pressed)
				win.refreshBrightness();
		}
	}

	// ─── Reusable tiles ─────────────────────────────────────────────

	// Samsung-style tile: big rounded icon badge (solid accent when on),
	// title + subtitle. The icon badge is the toggle (glows when on);
	// clicking the body opens details when hasDetails, otherwise it also
	// toggles. No chevron: the icon MouseArea sits above the body one and
	// composed clicks do not propagate, so the two actions never fire
	// together.
	component SamsungTile: Rectangle {
		id: stile

		property string icon: ""
		property string title: ""
		property string subtitle: ""
		property bool active: false
		property color activeColor: Theme.accentBlue
		property bool hasDetails: false
		signal iconClicked()
		signal bodyClicked()

		Layout.fillWidth: true
		Layout.preferredHeight: 88
		color: bodyArea.containsMouse ? Theme.bgHover : (stile.active ? Qt.rgba(stile.activeColor.r, stile.activeColor.g, stile.activeColor.b, 0.14) : Theme.bgMain)
		border.color: stile.active ? Qt.rgba(stile.activeColor.r, stile.activeColor.g, stile.activeColor.b, 0.70) : Theme.border
		border.width: 1
		radius: Theme.roundingElement

		Behavior on color {
			ColorAnimation { duration: 120 }
		}
		Behavior on border.color {
			ColorAnimation { duration: 120 }
		}

		MouseArea {
			id: bodyArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: {
				if (stile.hasDetails)
					stile.bodyClicked();
				else
					stile.iconClicked();
			}
		}

		RowLayout {
			anchors.fill: parent
			anchors.leftMargin: 12
			anchors.rightMargin: 12
			spacing: 12

			Rectangle {
				Layout.alignment: Qt.AlignVCenter
				Layout.preferredWidth: 52
				Layout.preferredHeight: 52
				radius: Theme.roundingElement
				color: stile.active ? stile.activeColor : (iconArea.containsMouse ? Theme.bgHover : Theme.bgCard)
				border.color: stile.active ? "transparent" : (iconArea.containsMouse ? Theme.textDim : Theme.border)
				border.width: 1

				Behavior on color {
					ColorAnimation { duration: 140 }
				}
				Behavior on border.color {
					ColorAnimation { duration: 120 }
				}

				Text {
					anchors.centerIn: parent
					text: stile.icon
					font.family: Theme.fontFamily
					font.pixelSize: 26
					font.bold: true
					color: stile.active ? Theme.bgMain : (iconArea.containsMouse ? Theme.textMain : Theme.textDim)
				}

				MouseArea {
					id: iconArea
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: stile.iconClicked()
				}
			}

			ColumnLayout {
				Layout.fillWidth: true
				Layout.alignment: Qt.AlignVCenter
				spacing: 3

				Text {
					Layout.fillWidth: true
					text: stile.title
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSizeSmall + 1
					font.bold: true
					color: Theme.textMain
					wrapMode: Text.Wrap
					maximumLineCount: 2
					elide: Text.ElideRight
				}

				Text {
					Layout.fillWidth: true
					text: stile.subtitle
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeSmall - 1
					color: Theme.textDim
					elide: Text.ElideRight
				}
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

	// Wide action button for the bottom row (momentary, not a toggle).
	component ActionButton: Rectangle {
		id: abtn

		property string icon: ""
		property string label: ""
		signal clicked()

		Layout.fillWidth: true
		Layout.preferredHeight: 48
		color: abtnArea.containsMouse ? Theme.bgHover : Theme.bgMain
		border.color: abtnArea.containsMouse ? Theme.textDim : Theme.border
		border.width: 1
		radius: Theme.roundingElement

		Behavior on color {
			ColorAnimation { duration: 120 }
		}
		Behavior on border.color {
			ColorAnimation { duration: 120 }
		}

		RowLayout {
			anchors.centerIn: parent
			spacing: 10

			Text {
				text: abtn.icon
				font.family: Theme.fontFamily
				font.pixelSize: 20
				font.bold: true
				color: abtnArea.containsMouse ? Theme.accentBlue : Theme.textDim
			}

			Text {
				text: abtn.label
				font.family: Theme.fontMono
				font.pixelSize: Theme.fontSizeSmall + 1
				font.bold: true
				color: Theme.textMain
			}
		}

		MouseArea {
			id: abtnArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: abtn.clicked()
		}
	}

	ColumnLayout {
		id: contentCol
		anchors.fill: parent
		spacing: 12

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

				Rectangle {
					implicitWidth: 28
					implicitHeight: 28
					radius: Theme.roundingElement
					color: closeArea.containsMouse ? Theme.bgHover : "transparent"
					border.color: closeArea.containsMouse ? Theme.textDim : Theme.border
					border.width: 1

					Behavior on color {
						ColorAnimation { duration: 120 }
					}

					Text {
						anchors.centerIn: parent
						text: "✕"
						font.pixelSize: 13
						color: closeArea.containsMouse ? Theme.critical : Theme.textDim
					}

					MouseArea {
						id: closeArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: QuickSettings.close()
					}
				}
			}

			// Subtle 1px separator
			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 1
				color: Theme.border
			}

			// ─── Volume slider ──────────────────────────────────
			RowLayout {
				Layout.fillWidth: true
				Layout.preferredHeight: 48
				spacing: 12

				Rectangle {
					Layout.preferredWidth: 48
					Layout.preferredHeight: 48
					radius: Theme.roundingElement
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
						// Leading-edge throttle: commit instantly for live
						// feedback, restart the timer for the trailing
						// commit so the final position always lands.
						if (volSettle.running)
							volSettle.restart();
						else {
							win.commitVolume();
							volSettle.restart();
						}
					}
				}

				Text {
					Layout.preferredWidth: 64
					horizontalAlignment: Text.AlignRight
					text: win.volReady ? (win.volMuted ? "Muted" : Math.round(volPill.pressed ? win.volShown : win.volPct) + "%") : "…"
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeSmall + 1
					font.bold: true
					color: Theme.textMain
				}
			}

			// ─── Brightness slider ──────────────────────────────
			RowLayout {
				Layout.fillWidth: true
				Layout.preferredHeight: 48
				spacing: 12

				Rectangle {
					Layout.preferredWidth: 48
					Layout.preferredHeight: 48
					radius: Theme.roundingElement
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
						// Same leading-edge throttle as volume above.
						if (briSettle.running)
							briSettle.restart();
						else {
							win.commitBrightness();
							briSettle.restart();
						}
					}
				}

				Text {
					Layout.preferredWidth: 64
					horizontalAlignment: Text.AlignRight
					text: win.brightnessReady ? win.brightness + "%" : "…"
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeSmall + 1
					font.bold: true
					color: Theme.textMain
				}
			}

			// ─── Toggle tiles ───────────────────────────────────
			GridLayout {
				Layout.fillWidth: true
				columns: 2
				columnSpacing: 8
				rowSpacing: 8

				SamsungTile {
					icon: win.wifiUp ? "󰖩" : "󰖪"
					title: "Wi-Fi"
					subtitle: win.wifiSubtitle
					active: Networking.wifiEnabled
					hasDetails: true
					onIconClicked: {
						if (Networking.wifiHardwareEnabled)
							Networking.wifiEnabled = !Networking.wifiEnabled;
					}
					onBodyClicked: win.openSpecial("impala")
				}

				SamsungTile {
					icon: win.btConnected > 0 ? "󰂲" : "󰂯"
					title: "Bluetooth"
					subtitle: win.btSubtitle
					active: win.btEnabled
					hasDetails: true
					onIconClicked: {
						if (win.btAdapter)
							win.btAdapter.enabled = !win.btAdapter.enabled;
					}
					onBodyClicked: win.openSpecial("bluetui")
				}

				SamsungTile {
					icon: "󰌪"
					title: "Battery saver"
					subtitle: powerSaveMarker.loaded ? "On · 60 Hz" : "Off · 165 Hz"
					active: powerSaveMarker.loaded
					activeColor: Theme.accentGreen
					hasDetails: true
					onIconClicked: {
						Quickshell.execDetached(["sh", "-c", "~/.local/bin/power-save.sh"]);
						markerRefresh.restart();
					}
					onBodyClicked: win.openSpecial("jolt")
				}

				SamsungTile {
					icon: "󰖔"
					title: "Night light"
					subtitle: win.nightLight ? "4500 K" : "Off"
					active: win.nightLight
					activeColor: Theme.warning
					onIconClicked: win.toggleNightLight()
				}

				SamsungTile {
					icon: Notifications.dnd ? "󰂛" : "󰂜"
					title: "Do not disturb"
					subtitle: Notifications.dnd ? "On" : "Off"
					active: Notifications.dnd
					activeColor: Theme.warning
					onIconClicked: Notifications.toggleDnd()
				}

				SamsungTile {
					icon: "󰖦"
					title: "Stay awake"
					subtitle: caffeineMarker.loaded ? "On" : "Off"
					active: caffeineMarker.loaded
					onIconClicked: {
						Quickshell.execDetached(["sh", "-c", "~/.local/bin/caffeine-toggle.sh"]);
						markerRefresh.restart();
					}
				}
			}

			// ─── Action button ──────────────────────────────────
			RowLayout {
				Layout.fillWidth: true
				spacing: 8

				ActionButton {
					icon: "󰐥"
					label: "Power"
					onClicked: {
						QuickSettings.close();
						Quickshell.execDetached(["qs", "ipc", "call", "shell", "summon", "launcher", "power"]);
					}
				}
			}
		}
}
