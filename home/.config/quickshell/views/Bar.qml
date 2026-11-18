import ".."
import "../widgets"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

PanelWindow {
	id: bar

	required property var modelData
	readonly property string screenName: modelData?.name ?? ""

	screen: modelData
	color: "transparent"
	// Overlay under fullscreen too: Hyprland fades a top layer in and out there, over the slide.
	// Mapped, its space stays reserved, so leaving fullscreen is one move.
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell"

	// Quickshell's own id of the focused one is right, and at once.
	readonly property int activeWorkspaceId: Hyprland.monitorFor(modelData)?.activeWorkspace?.id ?? -1
	// Over a fullscreen window only while Bars.peekScreen brings it; it slides down from the edge.
	readonly property bool overFullscreen: Hypr.fullscreenOn(modelData)
	readonly property bool peeking: overFullscreen && Bars.peekScreen === screenName
	// The bar slides up off the screen and back, as Hyprland moves the window (windows, easeOutQuint).
	property real shown: !overFullscreen || peeking ? 1 : 0
	Behavior on shown {
		NumberAnimation { duration: Theme.animNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1] }
	}
	// A window alone fills the screen below the bar (look.lua). The bar stays on the wallpaper;
	// in Focus it sits on a band joined to the window.
	readonly property bool focusLook: Notifications.dnd && Prefs.values.focusWallpaper
	readonly property bool lone: Theme.fillSingle && Hypr.loneOn(modelData) && focusLook
	// The band stays solid while the bar slides: over the lone window, and back over a fullscreen one.
	property bool peekBand: false
	onPeekingChanged: {
		if (peeking) {
			peekBand = true;
			// A resting pointer gets no enter as the strip grows under it (StandbyWindow's rule).
			pointerFollows.restart();
		}
	}
	Timer {
		id: pointerFollows
		interval: 40
		onTriggered: Hypr.refreshPointer()
	}
	onShownChanged: {
		if (shown === 0)
			peekBand = false;
	}
	onOverFullscreenChanged: {
		if (!overFullscreen && Bars.peekScreen === screenName)
			Bars.peekScreen = "";
		if (!overFullscreen)
			peekBand = false;
	}

	anchors {
		top: true
		left: true
		right: true
	}

	// Only the strip takes input. Over a fullscreen or lone window the margin below too, for the
	// band, and the band's rounded corners into the lone window.
	implicitHeight: Theme.barMarginY * (overFullscreen || lone ? 2 : 1) + Theme.barHeight + (lone ? Theme.roundingWindow : 0)
	mask: Region {
		item: strip

		Region {
			item: peekArea
		}
	}
	exclusionMode: ExclusionMode.Normal
	exclusiveZone: Theme.barMarginY + Theme.barHeight - Theme.barGapTrim

	// Hyprland only reports the visible special through events; the monitor
	// snapshot covers the time before the first one arrives.
	property var specialEvent: null
	readonly property string visibleSpecial: String(specialEvent ?? Hyprland.monitorFor(modelData)?.lastIpcObject?.specialWorkspace?.name ?? "").replace(/^special:/, "")
	// Joined first so the list only changes when the set of specials does.
	readonly property string specialsKey: Hypr.specials
		.filter(n => Specials.find(n)?.inBar !== false)
		.sort()
		.join("\n")

	Connections {
		target: Hyprland
		function onRawEvent(ev) {
			if (ev.name !== "activespecial")
				return;
			var parts = String(ev.data ?? "").split(",");
			if (parts.pop() === bar.screenName)
				bar.specialEvent = parts.join(",");
		}
	}

	// A click on a module puts the open panel away, unless it is the module's own
	// (`except`).
	function leavePanels(except: string): void {
		if (Panels.active !== "" && Panels.active !== except)
			Panels.close();
	}

	function playerFor(special: string): var {
		return Mpris.players.values.find(p => ((p?.desktopEntry ?? "") + " " + (p?.identity ?? "")).toLowerCase().includes(special)) ?? null;
	}

	Leaving {
		id: workspaceDots
		values: Hypr.workspaces.filter(w => w.monitor === bar.screenName).map(w => w.id)
	}

	Leaving {
		id: specialIcons
		values: bar.specialsKey !== "" ? bar.specialsKey.split("\n") : []
	}

	// The name of the special under the pointer, beside the row: said in the row, it would
	// push the next icon from under the pointer.
	property string specialHint: ""
	property string lastSpecialHint: ""
	onSpecialHintChanged: {
		if (specialHint !== "")
			lastSpecialHint = specialHint;
	}

	// Colours: blue is on screen or wants attention, green running, dim off; readouts
	// are textMain, the workspaces textDim.

	// The bar has no background of its own, so hover is a tint rather than a solid fill.
	readonly property color hoverColor: Theme.alpha(Theme.textMain, 0.1)

	component Pill: Rectangle {
		id: pill

		property string text: ""
		property string icon: ""
		property string value: ""
		property color textColor: Theme.textMain
		property bool isActive: false
		// The panel this module opens, if any.
		property string panel: ""
		property bool custom: false
		// A readout only: no hover, no clicks.
		property bool interactive: true
		// Hover says more, but a click does nothing.
		property bool clickable: true
		// On the bar; it opens up and closes in place.
		property bool shown: true
		// Lit for a moment: something happened.
		property real flash: 0
		// For a mark that shows the date.
		property int iconDay: 0
		// Room on each side of the content.
		property int inset: 7
		readonly property bool hovered: pillArea.containsMouse
		readonly property real mouseX: pillArea.mouseX
		readonly property bool wanted: shown && (text !== "" || icon !== "" || value !== "" || custom)
		property real revealed: 0
		default property alias content: pillRow.data
		signal activated()
		signal rightClicked()
		// On the button's release: while it is held, Hyprland keeps the focus on the bar.
		signal released()

		Layout.alignment: Qt.AlignVCenter
		implicitHeight: Theme.barHeight
		implicitWidth: (pillRow.implicitWidth + inset * 2) * revealed
		visible: revealed > 0
		opacity: revealed
		clip: revealed < 1
		color: isActive ? Theme.tint() : (hovered && clickable ? bar.hoverColor : "transparent")
		radius: Theme.roundingElement

		Component.onCompleted: revealed = Qt.binding(() => wanted ? 1 : 0)

		Behavior on revealed {
			NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
		}
		Behavior on color {
			ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
		}

		Press {
			id: pillPress
			target: pillFace
		}

		Lit {
			id: pillFace
			anchors.centerIn: parent
			halo: true
			lit: pill.hovered
			rest: pill.textColor
			flash: pill.flash

		Row {
			id: pillRow
			spacing: pill.custom ? 10 : 6

			LineIcon {
				anchors.verticalCenter: parent.verticalCenter
				name: pill.icon
				day: pill.iconDay
				color: pill.textColor
			}

			StyledText {
				anchors.verticalCenter: parent.verticalCenter
				visible: pill.text !== ""
				text: pill.text
				font.pixelSize: Theme.fontSizeLarge
				font.bold: true
				color: pill.textColor
			}

			StyledText {
				anchors.verticalCenter: parent.verticalCenter
				visible: pill.value !== ""
				text: pill.value
				mono: true
				font.pixelSize: Theme.fontSizeBar
				font.bold: true
				color: pill.textColor
			}
		}
		}

		MouseArea {
			id: pillArea
			anchors.fill: parent
			enabled: pill.interactive
			hoverEnabled: true
			cursorShape: pill.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
			acceptedButtons: Qt.LeftButton | Qt.RightButton
			onPressed: mouse => {
				if (pill.clickable)
					pillPress.restart();
				if (pill.panel === "" || mouse.button !== Qt.LeftButton)
					bar.leavePanels(pill.panel);
				if (mouse.button === Qt.RightButton)
					pill.rightClicked();
				else
					pill.activated();
			}
			onClicked: mouse => {
				if (mouse.button === Qt.LeftButton)
					pill.released();
			}
		}
	}

	// The pointer gone from it for a moment, and no panel on screen, a closing one either: away again.
	HoverHandler {
		id: peekHover
	}

	Timer {
		interval: 200
		running: bar.peeking && !peekHover.hovered && Panels.active === "" && Panels.windowsShown === 0
		onTriggered: Bars.peekScreen = ""
	}

	// The whole height takes the pointer while it is back: the edge above the strip too.
	Item {
		id: peekArea
		width: parent.width
		height: bar.peeking ? parent.height : 0
	}

	TrayMenu {
		id: trayMenu
	}

	// The level and the time it gives, and why the battery is blue.
	BarTip {
		target: system
		shown: system.hovered && !system.overBt && Battery.present && Panels.active !== "actions"
		text: [Battery.summary, Modes.awake ? "Keep awake: the screen stays on" : "", Modes.batteryCare ? "Battery care: stops short of full" : ""].filter(t => t !== "").join("\n")
	}

	// A tray app's name under it, as the specials say theirs.
	property Item trayHovered: null
	property Item trayTipTarget: system
	onTrayHoveredChanged: {
		if (trayHovered)
			trayTipTarget = trayHovered;
	}

	BarTip {
		target: bar.trayTipTarget
		shown: bar.trayHovered !== null && !trayMenu.visible
		text: bar.trayHovered ? (bar.trayHovered.modelData.tooltipTitle || bar.trayHovered.modelData.title || bar.trayHovered.modelData.id) : ""
	}

	BarTip {
		target: btIcon
		gap: (Theme.barHeight - btIcon.height) / 2 + 6
		shown: system.overBt && Panels.active !== "actions"
		text: Bt.connected.map(d => Bt.name(d) + (d.batteryAvailable ? "  " + Math.round(d.battery * 100) + "%" : "")).join("\n")
	}

	// The bar on a solid band, as much above it as below: joined to a lone window in Focus, and
	// over a fullscreen one, where a bright video hides it otherwise. Solid while it slides.
	property real bandFade: lone ? 1 : 0
	Behavior on bandFade {
		NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
	}
	// Focus paints the wallpaper bgMain, which the windows' GitHub Dark share: a band of the
	// darker shadow black keeps the bar apart.
	property color bandColor: focusLook ? Theme.shadow : Theme.bgMain
	Behavior on bandColor {
		ColorAnimation { duration: 600; easing.type: Easing.InOutSine }
	}
	readonly property int bandHeight: Theme.barMarginY * 2 + Theme.barHeight

	// Slides off as far as the window grows, so its edge stays on the window's. Back at once on
	// leaving fullscreen: Hyprland moves the window before the shell hears of it.
	Item {
		width: parent.width
		height: bar.bandHeight + Theme.roundingWindow
		y: bar.overFullscreen ? -(1 - bar.shown) * bar.bandHeight : 0
		opacity: bar.peekBand ? 1 : bar.bandFade
		visible: opacity > 0

		Rectangle {
			width: parent.width
			height: bar.bandHeight
			color: bar.bandColor
		}

		// Concave corners: the lone window looks rounded at the top, unlike a fullscreen one.
		Repeater {
			model: bar.lone && !bar.peekBand ? 2 : 0

			Item {
				required property int index
				x: index === 0 ? 0 : parent.width - width
				y: bar.bandHeight
				width: Theme.roundingWindow
				height: width
				clip: true
				opacity: bar.shown

				Rectangle {
					readonly property int r: Theme.roundingWindow
					x: parent.index === 0 ? -r : -2 * r
					y: -r
					width: 4 * r
					height: 4 * r
					radius: 2 * r
					color: "transparent"
					border.color: bar.bandColor
					border.width: r
				}
			}
		}
	}

	Item {
		id: strip
		x: Theme.barMarginX
		y: Theme.barMarginY - (1 - bar.shown) * bar.bandHeight
		width: parent.width - Theme.barMarginX * 2
		height: Theme.barHeight

		MouseArea {
			anchors.fill: parent
			z: -1
			enabled: Panels.active !== "" || bar.visibleSpecial !== ""
			// Panels first; with none open, the click puts the special away.
			property bool hides: false
			onPressed: {
				hides = Panels.active === "";
				Panels.close();
			}
			onReleased: {
				if (hides && bar.visibleSpecial !== "")
					Hypr.toggleSpecial(bar.visibleSpecial);
			}
		}

		RowLayout {
			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			spacing: 6

			Pill {
				icon: "search"
				textColor: isActive ? Theme.accentBlue : Theme.textMain
				isActive: Panels.active === "launcher"
				panel: "launcher"
				onActivated: Panels.toggle("launcher", "apps")
				onRightClicked: Panels.toggle("launcher", "windows")
			}

			Row {
				Layout.alignment: Qt.AlignVCenter
				height: Theme.barHeight
				layer.enabled: true
				layer.effect: Halo {}

				Repeater {
					model: ScriptModel {
						values: workspaceDots.shown
					}

					delegate: Item {
						id: wsButton
						required property int modelData
						readonly property bool active: bar.activeWorkspaceId === modelData
						readonly property bool wanted: workspaceDots.values.includes(modelData)
						property real revealed: 0

						height: Theme.barHeight
						width: (wsDot.width + 10) * revealed
						opacity: revealed

						Component.onCompleted: revealed = Qt.binding(() => wanted ? 1 : 0)

						Behavior on revealed {
							NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
						}

						Rectangle {
							id: wsDot
							anchors.centerIn: parent
							width: wsButton.active ? 26 : 8
							height: 8
							radius: 4
							color: wsButton.active ? Theme.accentBlue : (wsArea.containsMouse ? Theme.textMain : Theme.textDim)

							Behavior on width {
								NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
							}
							Behavior on color {
								ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
							}
						}

						Press {
							id: wsPress
							target: wsDot
						}

						MouseArea {
							id: wsArea
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onPressed: wsPress.restart()
							onClicked: {
								bar.leavePanels("");
								Hypr.focusWorkspace(wsButton.modelData);
							}
						}
					}
				}
			}

			// The activity special, with the memory's number once it is high; the other open
			// specials follow it, side by side. Actions always has the number.
			Row {
				Layout.alignment: Qt.AlignVCenter

				Pill {
					readonly property bool high: Memory.percent > 70

					shown: high || Hypr.specials.includes("activity")
					interactive: Specials.find("activity") !== null
					icon: "memory-stick"
					value: high ? Memory.percent + "%" : ""
					isActive: bar.visibleSpecial === "activity"
					textColor: Memory.percent >= 90 ? Theme.critical
						: Memory.percent >= 75 ? Theme.warning
						: isActive ? Theme.accentBlue : Theme.textDim
					onReleased: Hypr.toggleSpecial("activity")
					onRightClicked: Hypr.closeSpecial("activity")
					// Its name on hover, as the other specials have.
					readonly property string hint: Specials.find("activity")?.title ?? "Activity Monitor"
					onHoveredChanged: {
						if (hovered)
							bar.specialHint = hint;
						else if (bar.specialHint === hint)
							bar.specialHint = "";
					}
					Component.onDestruction: {
						if (bar.specialHint === hint)
							bar.specialHint = "";
					}
				}

				// The app's mark (LineIcons.brands), as the tray shows its apps:
				// blue while it is on screen, green while it plays something.
				Repeater {
					model: ScriptModel {
						values: specialIcons.shown
					}

					delegate: Pill {
						id: specialPill
						required property string modelData
						readonly property var special: Specials.find(modelData)
						readonly property var player: special?.player ? bar.playerFor(special.player) : null

						// An app of your own has no mark: its theme icon, in the bar's colour.
						readonly property string themeIcon: icon === "" && special?.appIcon !== "web-browser" ? Quickshell.iconPath(special?.appIcon ?? "", true) : ""

						icon: special?.icon ?? ""
						iconDay: clock.now.getDate()
						custom: themeIcon !== ""
						shown: specialIcons.values.includes(modelData)
						value: icon === "" && themeIcon === "" ? modelData.charAt(0).toUpperCase() : ""
						isActive: modelData === bar.visibleSpecial
						textColor: isActive ? Theme.accentBlue : (player?.isPlaying ? Theme.accentGreen : Theme.textDim)
						// What it plays, or what it is.
						readonly property string hint: player?.trackTitle ? [player.trackArtist, player.trackTitle].filter(t => t).join(" – ") : special?.title ?? modelData
						// Leaving one comes after entering the next: only its own name goes.
						onHoveredChanged: {
							if (hovered)
								bar.specialHint = hint;
							else if (bar.specialHint === hint)
								bar.specialHint = "";
						}
						onHintChanged: {
							if (hovered)
								bar.specialHint = hint;
						}
						Component.onDestruction: {
							if (bar.specialHint === hint)
								bar.specialHint = "";
						}
						onReleased: Hypr.toggleSpecial(modelData)
						onRightClicked: Hypr.closeSpecial(modelData)

						IconImage {
							anchors.verticalCenter: parent.verticalCenter
							visible: specialPill.themeIcon !== ""
							implicitSize: 16
							source: specialPill.themeIcon
							layer.enabled: true
							layer.effect: MultiEffect {
								saturation: -1.0
								colorization: 1.0
								colorizationColor: specialPill.textColor
							}
						}
					}
				}
			}

			StyledText {
				id: hintText
				Layout.alignment: Qt.AlignVCenter
				Layout.leftMargin: 2
				Layout.maximumWidth: 360
				visible: opacity > 0
				text: bar.lastSpecialHint
				font.pixelSize: Theme.fontSizeBar
				font.bold: true
				color: Theme.textMain
				elide: Text.ElideRight
				opacity: bar.specialHint !== "" ? 1 : 0
				layer.enabled: true
				layer.effect: Halo {}
				transform: Translate {
					x: (hintText.opacity - 1) * 6
				}

				Behavior on opacity {
					NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
				}
			}
		}

		// The timer's time left, as the OSD draws a level; the OSD takes its place for the moment.
		BarCountdown {
			wanted: Modes.timerLeft > 0 && Bars.osdScreen !== bar.screenName
			secondsLeft: Modes.timerLeft
			total: Modes.timerEnd - Modes.timerStart
			icon: "timer"
			tone: Theme.accentBlue
		}

		// Focus that ends on its own counts down there too, while the timer is off.
		BarCountdown {
			wanted: Notifications.focusLeft > 0 && Modes.timerLeft === 0 && Bars.osdScreen !== bar.screenName
			secondsLeft: Notifications.focusLeft
			total: (Notifications.dndUntil - Notifications.dndFrom) / 1000
			icon: "bell-off"
			tone: Theme.warning
		}

		// What comes and goes stands first: the row grows to the left, so the rest stays put.
		RowLayout {
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			spacing: 0

			// The tray apps that have something to show (Discord, Steam), in the bar's colour;
			// click as the app does, right-click for its menu.
			Repeater {
				model: ScriptModel {
					values: SystemTray.items.values.filter(i => i.status !== Status.Passive)
				}

				delegate: Pill {
					id: trayPill
					required property SystemTrayItem modelData

					custom: true
					onHoveredChanged: {
						if (hovered)
							bar.trayHovered = trayPill;
						else if (bar.trayHovered === trayPill)
							bar.trayHovered = null;
					}
					Component.onDestruction: {
						if (bar.trayHovered === trayPill)
							bar.trayHovered = null;
						if (bar.trayTipTarget === trayPill)
							bar.trayTipTarget = system;
					}
					onActivated: modelData.onlyMenu ? showMenu() : modelData.activate()
					onRightClicked: modelData.hasMenu ? showMenu() : modelData.secondaryActivate()

					function showMenu(): void {
						trayMenu.open(trayPill, modelData.menu);
					}

					IconImage {
						readonly property bool colored: trayPill.hovered || trayPill.modelData.status === Status.NeedsAttention

						anchors.verticalCenter: parent.verticalCenter
						implicitSize: 16
						source: trayPill.modelData.icon
						layer.enabled: !colored
						layer.effect: MultiEffect {
							saturation: -1.0
							colorization: 1.0
							colorizationColor: Theme.textMain
						}
					}
				}
			}

			Pill {
				id: dictationPill
				readonly property bool listening: Modes.dictation === "recording"

				// Listening in red, a click stops it; then writing it out, until the text is typed.
				shown: Modes.dictation !== ""
				custom: true
				textColor: listening ? Theme.critical : Theme.textMain
				isActive: true
				interactive: listening
				onActivated: Commands.script("dictation stop")

				Item {
					anchors.verticalCenter: parent.verticalCenter
					implicitWidth: listeningDots.visible ? listeningDots.implicitWidth : writing.implicitWidth
					implicitHeight: 16

					// Listening: three dots that stretch with the voice, the middle one most, each a
					// moment after the last; dots again in a quiet room.
					Row {
						id: listeningDots
						anchors.verticalCenter: parent.verticalCenter
						visible: dictationPill.listening
						spacing: 3

						Repeater {
							model: 3

							Rectangle {
								required property int index

								anchors.verticalCenter: parent.verticalCenter
								width: 4
								height: 4 + (index === 1 ? 10 : 6) * Audio.micLevel
								radius: 2
								color: dictationPill.textColor

								Behavior on height {
									NumberAnimation { duration: 60 + 40 * index; easing.type: Easing.OutCubic }
								}
							}
						}
					}

					// Writing it out: the dots slide onto a ring and orbit with a tail, blue to purple.
					Item {
						id: writing
						property real t: 0
						property real into: 0
						readonly property color start: Theme.critical
						readonly property color blue: Theme.accentBlue
						readonly property color purple: Theme.accentPurple

						function mix(a, b, k) {
							return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1);
						}

						anchors.fill: parent
						implicitWidth: 18
						visible: !dictationPill.listening

						NumberAnimation on into {
							running: writing.visible
							from: 0
							to: 1
							duration: 170
							easing.type: Easing.OutCubic
						}

						// 40.8 s: a whole number of turns (0.85 s) and of colour sweeps (2.4 s).
						NumberAnimation on t {
							running: writing.visible
							from: 0
							to: 40.8
							duration: 40800
							loops: Animation.Infinite
						}

						Repeater {
							model: 12

							Rectangle {
								required property int index
								readonly property int dot: index % 3
								readonly property int tail: Math.floor(index / 3)
								readonly property real e: writing.into
								readonly property real a: 2 * Math.PI * (writing.t / 0.85 - tail * 0.035 + dot / 3) - Math.PI / 2
								readonly property real sweep: 0.5 - 0.5 * Math.cos(2 * Math.PI * (dot / 3 + writing.t / 2.4))

								x: writing.width / 2 + (1 - e) * (dot - 1) * 7 + e * 5 * Math.cos(a) - width / 2
								y: writing.height / 2 + e * 5 * Math.sin(a) - height / 2
								z: -tail
								width: tail === 0 ? 3.6 : 3.2 - tail * 0.5
								height: width
								radius: width / 2
								visible: tail === 0 || e >= 0.6
								opacity: tail === 0 ? 1 : 0.45 - tail * 0.1
								color: writing.mix(writing.start, writing.mix(writing.blue, writing.purple, sweep), e)
							}
						}
					}
				}
			}

			Pill {
				shown: Modes.recording
				text: "●"
				value: "REC"
				textColor: Theme.critical
				isActive: true
				onActivated: Commands.run("record")
			}

			Pill {
				shown: Modes.screencasts > 0 && !Modes.listingWindows
				interactive: false
				icon: "screen-share"
				textColor: Theme.accentPurple
				isActive: true
			}

			Pill {
				shown: Weather.current !== null && Prefs.values.weather
				icon: Weather.current?.icon ?? ""
				value: Weather.current ? Weather.current.tempNum + "°" : ""
				isActive: Panels.active === "weather"
				panel: "weather"
				onActivated: Panels.toggle("weather")
			}

			Pill {
				id: system
				// The pill's MouseArea takes the hover: up to halfway into the gap after the icon.
				readonly property bool overBt: hovered && btIcon.visible
					&& mouseX < btIcon.mapToItem(system, btIcon.width + 5, 0).x

				custom: true
				isActive: Panels.active === "actions"
				panel: "actions"
				onActivated: Panels.toggle("actions")

				// Only with a device: on or off says nothing worth the room.
				LineIcon {
					id: btIcon
					anchors.verticalCenter: parent.verticalCenter
					visible: Bt.connected.length > 0
					name: Bt.icon
					color: Theme.textMain
				}

				// Only when down; online, only with no battery to open Actions by.
				LineIcon {
					anchors.verticalCenter: parent.verticalCenter
					visible: !Net.online || !Battery.present
					name: Net.icon
					color: Modes.awake ? Theme.accentBlue : Net.online ? Theme.textMain : Theme.textDim
				}

				BatteryIcon {
					id: batteryIcon
					anchors.verticalCenter: parent.verticalCenter
					// One colour at a time: running low comes first, then keep awake.
					color: Modes.awake && !Battery.critical ? Theme.accentBlue : Battery.color
					percent: Prefs.values.batteryPercent
				}
			}

			// The date and the time, and the notifications behind a click, as on a Mac. A dot at
			// the time's corner: blue for notifications kept, yellow while they are held back (Focus).
			Pill {
				id: clock
				property date now: new Date()
				readonly property int count: Notifications.history.count
				property int seen: 0

				custom: true
				// Room for the dot on the right, the same on the left: the text stays centred.
				inset: 14
				isActive: Panels.active === "notifications"
				panel: "notifications"
				onActivated: Panels.toggle("notifications")
				onCountChanged: {
					if (count > seen && !Notifications.quiet)
						arrived.restart();
					seen = count;
				}
				Component.onCompleted: seen = count

				StyledText {
					anchors.verticalCenter: parent.verticalCenter
					text: clock.now.toLocaleDateString(Qt.locale("en_GB"), Prefs.values.clockWeekday ? "ddd d MMM" : "d MMM")
					font.bold: true
					font.pixelSize: Theme.fontSizeBar
				}

				StyledText {
					id: time
					anchors.verticalCenter: parent.verticalCenter
					text: Qt.formatDateTime(clock.now, (Prefs.values.clock24 ? "hh:mm" : "h:mm") + (Prefs.values.clockSeconds ? ":ss" : "") + (Prefs.values.clock24 ? "" : " AP"))
					mono: true
					font.bold: true
					font.pixelSize: Theme.fontSizeBar
				}

				// In the pill's margin, out of the row, whose light is cut to what the row holds.
				Rectangle {
					id: mark
					readonly property bool kept: clock.count > 0

					parent: clock
					x: clock.width - clock.inset + 5
					y: (clock.height - time.implicitHeight) / 2 + 3
					width: 6
					height: 6
					radius: 3
					visible: kept || Notifications.quiet
					color: !kept ? "transparent" : Notifications.quiet ? Theme.warning : Theme.accentBlue
					border.width: kept ? 0 : 1.5
					border.color: Theme.warning

					// Pops once as one comes in.
					SequentialAnimation {
						id: arrived
						NumberAnimation { target: mark; property: "scale"; to: 1.8; duration: Theme.animFast; easing.type: Easing.OutCubic }
						NumberAnimation { target: mark; property: "scale"; to: 1; duration: Theme.animNormal; easing.type: Easing.InOutSine }
					}
				}

				// Not SystemClock, which spins in the hour a DST change repeats; a second's tick
				// is at most a second stale after resume.
				Timer {
					running: true
					repeat: true
					onTriggered: clock.now = new Date()
				}
			}
		}
	}
}
