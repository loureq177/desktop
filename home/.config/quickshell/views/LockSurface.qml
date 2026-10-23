import ".."
import "../widgets"
import Quickshell
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

	SystemClock {
		id: clock
		// Seconds, not Minutes: see the clock in Bar.qml.
		precision: SystemClock.Seconds
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

	// One changing pixel is enough to make the surface commit, see the context.
	Rectangle {
		width: 1
		height: 1
		color: root.context.nudge ? "#01000000" : "#02000000"
	}

	MouseArea {
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.BlankCursor
		onPressed: field.focusInput()
	}

	Item {
		anchors.fill: parent
		opacity: root.reveal

		StyledText {
			anchors.centerIn: parent
			anchors.verticalCenterOffset: -160
			text: Qt.formatDateTime(clock.date, "HH:mm")
			font.pixelSize: 128
			font.bold: true
		}

		StyledText {
			anchors.centerIn: parent
			anchors.verticalCenterOffset: -80
			text: clock.date.toLocaleDateString(Qt.locale(), "dddd, dd MMMM yyyy")
			font.pixelSize: 24
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

				LineIcon {
					anchors.verticalCenter: parent.verticalCenter
					name: "lock"
					color: Theme.textMain
					size: Theme.fontSizeLarge
				}

				StyledText {
					anchors.verticalCenter: parent.verticalCenter
					text: Quickshell.env("USER")
					mono: true
					font.bold: true
				}
			}

			Row {
				anchors.right: parent.right
				anchors.verticalCenter: parent.verticalCenter
				spacing: 20

				LineIcon {
					anchors.verticalCenter: parent.verticalCenter
					name: SystemStatus.netIcon
					color: SystemStatus.online ? Theme.accentBlue : Theme.textDim
					size: Theme.fontSizeLarge
				}

				StyledText {
					anchors.verticalCenter: parent.verticalCenter
					visible: SystemStatus.batteryDevice !== null
					text: SystemStatus.batteryPct + "%"
					color: SystemStatus.batteryFull ? Theme.accentGreen : SystemStatus.batteryTint
					mono: true
					font.bold: true
				}

				// Count only: what the notifications say stays behind the lock.
				Row {
					readonly property int count: Notifications.history.count

					anchors.verticalCenter: parent.verticalCenter
					spacing: 6
					visible: Notifications.dnd || count > 0

					LineIcon {
						anchors.verticalCenter: parent.verticalCenter
						name: Notifications.dnd ? "bell-off" : "bell"
						color: Notifications.dnd ? Theme.warning : Theme.accentBlue
						size: Theme.fontSizeLarge
					}

					StyledText {
						anchors.verticalCenter: parent.verticalCenter
						visible: parent.count > 0
						text: parent.count
						color: Notifications.dnd ? Theme.warning : Theme.accentBlue
						mono: true
						font.bold: true
					}
				}
			}
		}

		PasswordField {
			id: field

			anchors.centerIn: parent
			anchors.verticalCenterOffset: 50
			width: parent.width * 0.2
			height: parent.height * 0.05
			focus: true
			readOnly: root.context.checking
			busy: root.context.checking
			failed: root.context.failText !== "" && text === ""
			message: root.context.failText

			onTextChanged: {
				if (root.context.password !== text)
					root.context.password = text;
				if (text !== "")
					root.context.failText = "";
			}
			onAccepted: root.context.submit()
			onCancelled: root.context.password = ""

			Component.onCompleted: focusInput()
			Component.onDestruction: {
				if (root.context.focusOwner === root)
					root.context.focusOwner = null;
			}
			onInputFocusedChanged: {
				if (inputFocused)
					root.context.focusOwner = root;
				else if (root.context.focusOwner === root)
					root.context.focusOwner = null;
			}

			Connections {
				target: root.context
				function onShownChanged() {
					if (root.context.shown)
						field.focusInput();
				}
				function onNudgeChanged() {
					field.focusInput();
				}
				function onPasswordChanged() {
					if (field.text !== root.context.password)
						field.text = root.context.password;
				}
			}
		}
	}
}
