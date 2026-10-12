import ".."
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Effects

Item {
	id: root

	required property var context
	required property ShellScreen screen

	// The fade waits for the screenshot and a first presented frame, so none of
	// it is lost to surface setup.
	readonly property bool backdropReady: backdrop.source == "" || backdrop.hasContent
	property bool ready: false
	property real reveal: context.shown && ready ? 1 : 0
	Behavior on reveal {
		NumberAnimation {
			duration: root.context.shown ? Theme.lockFadeIn : Theme.lockFadeOut
			easing.type: Easing.InOutSine
		}
	}

	Timer {
		interval: 50
		running: root.backdropReady
		onTriggered: root.ready = true
	}

	Timer {
		interval: 400
		running: true
		onTriggered: root.ready = true
	}

	readonly property var batteryDevice: {
		var vals = UPower.devices.values;
		for (var i = 0; i < vals.length; i++)
			if (vals[i].isLaptopBattery && vals[i].isPresent)
				return vals[i];
		return null;
	}

	function networkUp(type): bool {
		var vals = Networking.devices.values;
		for (var i = 0; i < vals.length; i++)
			if (vals[i].type === type && vals[i].connected)
				return true;
		return false;
	}

	SystemClock {
		id: clock
		precision: SystemClock.Minutes
	}

	Image {
		id: backdrop
		readonly property bool hasContent: status === Image.Ready
		anchors.fill: parent
		source: root.context.backdropSource(root.screen)
		fillMode: Image.PreserveAspectCrop
		// The wallpaper is already decoded for the desktop at this very size; a
		// screenshot is taken fresh every time and must not be cached.
		sourceSize: root.context.showBackdrop ? undefined : Wallpaper.decodeSize(root.screen)
		cache: !root.context.showBackdrop
		// Only a screenshot is shown sharp, as the desktop the blur grows out of.
		visible: hasContent && root.context.showBackdrop
	}

	// Blurred once into a cached layer and crossfaded over the sharp screenshot;
	// animating the blur radius itself re-renders every frame and stutters.
	Item {
		anchors.fill: parent
		visible: backdrop.hasContent
		opacity: root.reveal
		layer.enabled: true

		MultiEffect {
			anchors.fill: parent
			source: backdrop
			autoPaddingEnabled: false
			blurEnabled: true
			blur: 1
			blurMax: Theme.lockBlurMax
			saturation: Theme.lockVibrancy
		}

		Rectangle {
			anchors.fill: parent
			color: "black"
			opacity: 1 - Theme.lockBrightness
		}
	}

	MouseArea {
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.BlankCursor
		onPressed: input.forceActiveFocus()
	}

	TextInput {
		id: input
		width: 0
		height: 0
		opacity: 0
		focus: true
		echoMode: TextInput.Password
		readOnly: root.context.checking

		onTextChanged: {
			if (root.context.password !== text)
				root.context.password = text;
			if (text !== "")
				root.context.failText = "";
		}
		Keys.onReturnPressed: root.context.submit()
		Keys.onEnterPressed: root.context.submit()
		Keys.onEscapePressed: root.context.password = ""

		Connections {
			target: root.context
			function onPasswordChanged() {
				if (input.text !== root.context.password)
					input.text = root.context.password;
			}
		}
	}

	Item {
		anchors.fill: parent
		opacity: root.reveal

		Text {
			anchors.centerIn: parent
			anchors.verticalCenterOffset: -160
			text: Qt.formatDateTime(clock.date, "HH:mm")
			color: Theme.textMain
			font.family: Theme.fontFamily
			font.pointSize: 96
			font.bold: true
		}

		Text {
			anchors.centerIn: parent
			anchors.verticalCenterOffset: -80
			text: clock.date.toLocaleDateString(Qt.locale(), "dddd, dd MMMM yyyy")
			color: Theme.textMain
			font.family: Theme.fontFamily
			font.pointSize: 18
		}

		// Mirrors the bar's geometry and type so the shell seems to stay put while
		// the desktop blurs away underneath it.
		Item {
			anchors.top: parent.top
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.topMargin: Theme.barMarginY
			anchors.leftMargin: Theme.barMarginX + 7
			anchors.rightMargin: Theme.barMarginX + 7
			height: Theme.barHeight

			Row {
				anchors.left: parent.left
				anchors.verticalCenter: parent.verticalCenter
				spacing: 6

				Text {
					anchors.verticalCenter: parent.verticalCenter
					text: "󰌾"
					color: Theme.textMain
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSizeBarIcon
					font.bold: true
				}

				Text {
					anchors.verticalCenter: parent.verticalCenter
					text: Quickshell.env("USER")
					color: Theme.textMain
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeBar
					font.bold: true
				}
			}

			Row {
				anchors.right: parent.right
				anchors.verticalCenter: parent.verticalCenter
				spacing: 20

				Text {
					readonly property bool wifiUp: root.networkUp(DeviceType.Wifi)
					readonly property bool wiredUp: root.networkUp(DeviceType.Wired)

					anchors.verticalCenter: parent.verticalCenter
					text: wifiUp ? "󰖩" : (wiredUp ? "󰈀" : "󰖪")
					color: wifiUp || wiredUp ? Theme.accentBlue : Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSizeBarIcon
					font.bold: true
				}

				Text {
					readonly property var device: root.batteryDevice
					readonly property int pct: device ? Math.round(device.percentage * 100) : 0
					readonly property bool full: device && device.state === UPowerDeviceState.FullyCharged
					readonly property bool charging: device && (device.state === UPowerDeviceState.Charging
						|| device.state === UPowerDeviceState.PendingCharge)

					anchors.verticalCenter: parent.verticalCenter
					visible: device !== null
					text: pct + "%"
					color: charging || full ? Theme.accentGreen
						: pct <= 10 ? Theme.critical
						: pct <= 20 ? Theme.warning
						: Theme.textMain
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeBar
					font.bold: true
				}

				// Count only: what the notifications say stays behind the lock.
				Row {
					readonly property int count: Notifications.history.length

					anchors.verticalCenter: parent.verticalCenter
					spacing: 6
					visible: Notifications.dnd || count > 0

					Text {
						anchors.verticalCenter: parent.verticalCenter
						text: Notifications.dnd ? "󰂛" : "󰂚"
						color: Notifications.dnd ? Theme.warning : Theme.accentBlue
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSizeBarIcon
						font.bold: true
					}

					Text {
						anchors.verticalCenter: parent.verticalCenter
						visible: parent.count > 0
						text: parent.count
						color: Notifications.dnd ? Theme.warning : Theme.accentBlue
						font.family: Theme.fontMono
						font.pixelSize: Theme.fontSizeBar
						font.bold: true
					}
				}
			}
		}

		Item {
			id: field

			readonly property bool failed: root.context.failText !== "" && root.context.password === ""
			readonly property real dotSize: height * 0.25

			anchors.centerIn: parent
			anchors.verticalCenterOffset: 50
			width: parent.width * 0.2
			height: parent.height * 0.05

			Rectangle {
				anchors.fill: parent
				radius: Theme.roundingWindow
				color: Theme.alpha(Theme.bgCard, 0.65)
			}

			Rectangle {
				id: outlineFill
				anchors.fill: parent
				visible: false
				layer.enabled: true
				gradient: Gradient {
					orientation: Gradient.Horizontal
					GradientStop {
						position: 0
						color: root.context.checking ? Theme.accentGreen : field.failed ? Theme.warning : Theme.accentBlue
					}
					GradientStop {
						position: 1
						color: root.context.checking ? Theme.accentBlue : field.failed ? Theme.critical : Theme.accentPurple
					}
				}
			}

			Rectangle {
				id: outlineMask
				anchors.fill: parent
				visible: false
				layer.enabled: true
				radius: Theme.roundingWindow
				color: "transparent"
				border.width: Theme.borderSize
				border.color: "black"
			}

			MultiEffect {
				anchors.fill: parent
				source: outlineFill
				maskEnabled: true
				maskSource: outlineMask
			}

			Item {
				anchors.fill: parent
				anchors.margins: Theme.paddingItem
				clip: true

				ListModel {
					id: dots
				}

				Connections {
					target: root.context
					function onPasswordChanged() {
						var len = root.context.password.length;
						while (dots.count < len)
							dots.append({});
						if (dots.count > len)
							dots.remove(len, dots.count - len);
					}
				}

				Row {
					anchors.verticalCenter: parent.verticalCenter
					x: (parent.width - width) / 2
					spacing: field.dotSize * 0.3

					Behavior on x {
						NumberAnimation {
							duration: Theme.lockDotsFade
							easing.type: Easing.OutCubic
						}
					}

					Repeater {
						model: dots
						Rectangle {
							width: field.dotSize
							height: field.dotSize
							radius: width / 2
							color: Theme.textMain

							NumberAnimation on opacity {
								from: 0
								to: 1
								duration: Theme.lockDotsFade
							}
							NumberAnimation on scale {
								from: 0.6
								to: 1
								duration: Theme.lockDotsFade
								easing.type: Easing.OutQuad
							}
						}
					}
				}

				Text {
					anchors.centerIn: parent
					width: parent.width
					visible: field.failed
					text: root.context.failText
					color: Theme.textMain
					horizontalAlignment: Text.AlignHCenter
					elide: Text.ElideRight
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSizeSmall
				}
			}
		}
	}
}
