// Weather panel: popup card showing current conditions, stats, and 3-day forecast.
// Directly mirrors the Omarchy Quattro weather popup with click-to-edit city search.
// Toggle via IPC: `qs ipc call weather toggle` (SUPER + W).
// ESC or clicking outside dismisses the panel.
import ".."
import "../widgets"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../WeatherModel.js" as WeatherModel

PanelWindow {
	id: root

	readonly property bool shown: Weather.panelOpen
	signal opened()
	signal dismissed()

	property int offscreenSlide: Math.max(700, card.height + Theme.notifTopMargin + 60)
	property int slide: offscreenSlide
	property real backdropOpacity: 0.0

	function requestDismiss() {
		if (Weather.editingLocation)
			Weather.cancelEditingLocation();
		else
			root.dismissed();
	}

	visible: shown || slideOut.running
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	exclusiveZone: 0

	WlrLayershell.layer: WlrLayer.Top
	WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell"

	HyprlandFocusGrab {
		active: root.shown
		windows: [ root ]
		onCleared: root.dismissed()
	}

	screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	onShownChanged: {
		if (shown) {
			slideOut.stop();
			slideIn.restart();
			chartCanvas.requestPaint();
			root.opened();
		} else {
			slideIn.stop();
			slideOut.restart();
		}
	}

	onOffscreenSlideChanged: {
		if (!shown && !slideIn.running && !slideOut.running)
			slide = offscreenSlide;
	}

	ParallelAnimation {
		id: slideIn

		NumberAnimation {
			target: root
			property: "slide"
			from: root.slide
			to: 0
			duration: Theme.animSmooth
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			from: root.backdropOpacity
			to: 1.0
			duration: Theme.animSmooth
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Theme.easeOutQuint
		}
	}

	ParallelAnimation {
		id: slideOut

		NumberAnimation {
			target: root
			property: "slide"
			from: root.slide
			to: root.offscreenSlide
			duration: Theme.animNormal
			easing.type: Easing.InCubic
		}
		NumberAnimation {
			target: root
			property: "backdropOpacity"
			from: root.backdropOpacity
			to: 0.0
			duration: Theme.animNormal
			easing.type: Easing.InCubic
		}
	}

	Shortcut {
		sequences: ["Esc"]
		enabled: root.visible
		onActivated: root.requestDismiss()
	}

	// Full-screen dim backdrop
	Rectangle {
		id: backdrop
		anchors.fill: parent
		color: Theme.backdropColor
		opacity: root.backdropOpacity

		MouseArea {
			anchors.fill: parent
			enabled: root.shown
			onPressed: {
				root.requestDismiss();
			}
		}
	}

	// Weather Card
	Rectangle {
		id: card
		anchors.horizontalCenter: parent.horizontalCenter
		y: Theme.notifTopMargin - root.slide
		width: Math.min(576, root.width - 32)
		height: weatherCol.implicitHeight + Theme.paddingCard * 2
		color: Theme.bgCard
		border.color: Theme.border
		border.width: Theme.borderSize
		radius: Theme.roundingWindow
		clip: true
		focus: true

		Behavior on height {
			NumberAnimation {
				duration: Theme.animNormal
				easing.type: Easing.BezierSpline
				easing.bezierCurve: Theme.easeOutQuint
			}
		}

		Keys.onEscapePressed: event => {
			root.requestDismiss();
			event.accepted = true;
		}

		Keys.onReturnPressed: event => {
			if (!Weather.editingLocation) {
				Weather.startEditingLocation();
				event.accepted = true;
			}
		}

		// Absorb mouse clicks inside the card.
		// Disabled with the panel so clicks during the slide-out
		// animation fall through instead of dying on a leaving card.
		MouseArea {
			anchors.fill: parent
			enabled: root.shown
			hoverEnabled: true
		}

		Column {
			id: weatherCol
			anchors.top: parent.top
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.margins: Theme.paddingCard
			spacing: 16

			// ─── Hero Row: Big Icon + Temp on left; Location + Stats on right ────
			Item {
				width: parent.width
				height: Math.max(heroLeft.implicitHeight, heroRight.implicitHeight)

				// Left: Big Condition Icon + Temp with High/Low underneath
				Row {
					id: heroLeft
					anchors.left: parent.left
					anchors.verticalCenter: parent.verticalCenter
					spacing: 14

					Text {
						id: heroIcon
						anchors.verticalCenter: parent.verticalCenter
						text: Weather.label || "—"
						color: Theme.textMain
						font.family: Theme.fontFamily
						font.pixelSize: 58
					}

					Column {
						anchors.verticalCenter: parent.verticalCenter
						spacing: 2

						Row {
							spacing: 2

							Text {
								id: tempBig
								text: Weather.tempNum || "—"
								color: Theme.textMain
								font.family: Theme.fontFamily
								font.pixelSize: 48
								font.bold: true
							}

							Text {
								text: Weather.current ? Weather.tempUnit : ""
								color: Theme.textDim
								font.family: Theme.fontFamily
								font.pixelSize: 18
								anchors.top: tempBig.top
								anchors.topMargin: 6
							}
						}

						Row {
							spacing: 6
							visible: !!(Weather.reportTodayHigh || Weather.reportTodayLow)

							Text {
								text: "↑" + (Weather.reportTodayHigh || "—")
								color: Theme.textMain
								font.family: Theme.fontFamily
								font.pixelSize: 13
								font.bold: true
							}

							Text {
								text: "↓" + (Weather.reportTodayLow || "—")
								color: Theme.textMuted
								font.family: Theme.fontFamily
								font.pixelSize: 13
								font.bold: true
							}
						}
					}
				}

				// Right: Location Title (Click to Edit) + Stats
				Column {
					id: heroRight
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					spacing: 8

					// Location Display (Click to Edit)
					Item {
						anchors.right: parent.right
						visible: !Weather.editingLocation
						width: locRow.implicitWidth
						height: locRow.implicitHeight

						Row {
							id: locRow
							spacing: 6

							Text {
								text: ""
								color: Theme.accentBlue
								font.family: Theme.fontFamily
								font.pixelSize: Theme.fontSizeSmall
								anchors.verticalCenter: parent.verticalCenter
							}

							Text {
								text: (Weather.reportLocation || "SET LOCATION").toUpperCase()
								color: locationArea.containsMouse ? Theme.textMain : Theme.textDim
								font.family: Theme.fontFamily
								font.pixelSize: Theme.fontSizeSmall
								font.bold: true
								font.letterSpacing: 1
								anchors.verticalCenter: parent.verticalCenter
							}

							Text {
								text: "󰏫"
								color: locationArea.containsMouse ? Theme.accentBlue : Theme.textMuted
								font.family: Theme.fontFamily
								font.pixelSize: 12
								anchors.verticalCenter: parent.verticalCenter
							}
						}

						MouseArea {
							id: locationArea
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: Weather.startEditingLocation()
						}
					}

					// Location Editor (when clicked)
					Row {
						id: editRow
						anchors.right: parent.right
						visible: Weather.editingLocation
						spacing: 6

						Rectangle {
							width: 200
							height: 32
							color: Theme.bgHover
							border.color: Theme.border
							border.width: 1
							radius: Theme.roundingElement

							TextInput {
								id: locationInput
								anchors.fill: parent
								anchors.leftMargin: 8
								anchors.rightMargin: 8
								verticalAlignment: TextInput.AlignVCenter
								// NOTE: no `text: Weather.configuredLocation`
								// binding — it breaks on first keystroke and
								// would then ignore external file updates.
								// Synced explicitly on show (below).
								color: Theme.textMain
								font.family: Theme.fontMono
								font.pixelSize: Theme.fontSizeSmall
								selectByMouse: true
								clip: true

								onVisibleChanged: {
									if (visible) {
										text = Weather.configuredLocation;
										selectAll();
										forceActiveFocus();
									}
								}

								onTextChanged: {
									if (Weather.editingLocation && !Weather.savingLocation)
										Weather.requestGeocode(text);
								}

								Keys.onEscapePressed: event => {
									Weather.cancelEditingLocation();
									event.accepted = true;
								}

								Keys.onDownPressed: event => {
									if (Weather.suggestionIndex < Weather.locationSuggestions.length - 1)
										Weather.suggestionIndex++;
									event.accepted = true;
								}

								Keys.onUpPressed: event => {
									if (Weather.suggestionIndex > 0)
										Weather.suggestionIndex--;
									event.accepted = true;
								}

								Keys.onReturnPressed: event => {
									Weather.commitLocation(text);
									event.accepted = true;
								}
							}
						}

						// Clear button / spinner
						Rectangle {
							width: 32
							height: 32
							color: clearArea.containsMouse ? Theme.bgHover : "transparent"
							border.color: Theme.border
							border.width: 1
							radius: Theme.roundingElement

							Text {
								anchors.centerIn: parent
								text: Weather.savingLocation ? "󰦖" : "✕"
								font.family: Theme.fontFamily
								color: Theme.textDim
								font.pixelSize: Theme.fontSizeSmall

								RotationAnimator on rotation {
									running: Weather.savingLocation
									from: 0
									to: 360
									duration: 800
									loops: Animation.Infinite
								}
							}

							MouseArea {
								id: clearArea
								anchors.fill: parent
								enabled: !Weather.savingLocation
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: Weather.clearLocation()
							}
						}
					}

					// Stats row (FEELS, WIND, HUMID)
					Row {
						id: weatherStats
						anchors.right: parent.right
						visible: !!Weather.current
						spacing: 20

						Column {
							id: feelsCol
							spacing: 3
							Text {
								text: "FEELS"
								color: Theme.textMuted
								font.family: Theme.fontFamily
								font.pixelSize: Theme.fontSizeGrid
								font.letterSpacing: 1
							}
							Text {
								text: Weather.reportFeels
								color: Theme.textMain
								font.family: Theme.fontFamily
								font.pixelSize: 16
								font.bold: true
							}
						}

						Column {
							spacing: 3
							Text {
								text: "WIND"
								color: Theme.textMuted
								font.family: Theme.fontFamily
								font.pixelSize: Theme.fontSizeGrid
								font.letterSpacing: 1
							}
							Text {
								text: Weather.reportWind
								color: Theme.textMain
								font.family: Theme.fontFamily
								font.pixelSize: 16
								font.bold: true
							}
						}

						Column {
							spacing: 3
							Text {
								text: "HUMID"
								color: Theme.textMuted
								font.family: Theme.fontFamily
								font.pixelSize: Theme.fontSizeGrid
								font.letterSpacing: 1
							}
							Text {
								text: Weather.reportHumidity
								color: Theme.textMain
								font.family: Theme.fontFamily
								font.pixelSize: 16
								font.bold: true
							}
						}
					}
				}
			}

			// ─── Geocoding suggestions dropdown (when editing) ─────────────────
			Column {
				visible: Weather.editingLocation && !Weather.savingLocation && Weather.locationSuggestions && Weather.locationSuggestions.length > 0
				width: parent.width
				spacing: 2

				Repeater {
					model: Weather.locationSuggestions

					Rectangle {
						required property var modelData
						required property int index
						width: parent.width
						height: 34
						radius: Theme.roundingElement
						color: index === Weather.suggestionIndex ? Theme.selectionBg : "transparent"
						border.color: index === Weather.suggestionIndex ? Theme.selectionBorder : "transparent"
						border.width: 1

						Row {
							anchors.fill: parent
							anchors.leftMargin: 12
							anchors.rightMargin: 12
							spacing: 8

							Text {
								anchors.verticalCenter: parent.verticalCenter
								text: modelData ? modelData.name : ""
								color: Theme.textMain
								font.family: Theme.fontFamily
								font.pixelSize: Theme.fontSizeSmall
								font.bold: true
							}

							Text {
								anchors.verticalCenter: parent.verticalCenter
								visible: !!(modelData && modelData.description)
								text: modelData && modelData.description ? modelData.description : ""
								color: Theme.textDim
								font.family: Theme.fontFamily
								font.pixelSize: Theme.fontSizeGrid
								elide: Text.ElideRight
							}
						}

						MouseArea {
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onPositionChanged: Weather.suggestionIndex = index
							onClicked: {
								if (modelData)
									Weather.pickSuggestion(modelData);
							}
						}
					}
				}
			}

			// Loading / error placeholder (Offline was infinite
			// "Fetching..." with retry only via 15-min timer or reopen).
			ColumnLayout {
				visible: !Weather.current
				width: parent.width
				spacing: 6

				Text {
					Layout.alignment: Qt.AlignHCenter
					text: Weather.lastError !== "" ? Weather.lastError : "Fetching weather..."
					color: Weather.lastError !== "" ? Theme.critical : Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSizeSmall
					font.italic: Weather.lastError === ""
				}

				Rectangle {
					visible: Weather.lastError !== ""
					Layout.alignment: Qt.AlignHCenter
					implicitWidth: retryLabel.implicitWidth + 18
					implicitHeight: 28
					radius: Theme.roundingSubtle
					color: retryArea.containsMouse ? Theme.bgHover : "transparent"
					border.color: retryArea.containsMouse ? Theme.textDim : Theme.border
					border.width: 1

					Text {
						id: retryLabel
						anchors.centerIn: parent
						text: "Retry"
						font.family: Theme.fontFamily
						font.pixelSize: Theme.fontSizeSmall - 1
						color: Theme.accentBlue
					}

					MouseArea {
						id: retryArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: mouse => {
							mouse.accepted = true;
							Weather.refresh();
						}
					}
				}
			}

			// ─── Divider ───────────────────────────────────────────────────────
			Rectangle {
				visible: Weather.hourlyForecast && Weather.hourlyForecast.length > 0
				width: parent.width
				height: 1
				color: Theme.border
			}

			// ─── Hourly Forecast with Chart (Samsung / Google Weather style) ───
			Flickable {
				id: hourlyFlick
				visible: Weather.hourlyForecast && Weather.hourlyForecast.length > 0
				width: parent.width
				height: 164
				contentWidth: Math.max(width, (Weather.hourlyForecast ? Weather.hourlyForecast.length : 0) * 54)
				contentHeight: height
				flickableDirection: Flickable.HorizontalFlick
				boundsBehavior: Flickable.DragAndOvershootBounds
				flickDeceleration: Theme.flickDecel
				maximumFlickVelocity: Theme.maxFlickVel
				clip: true

				MouseArea {
					anchors.fill: parent
					acceptedButtons: Qt.NoButton
					onWheel: w => {
						hourlyFlick.contentX = Math.max(0, Math.min(hourlyFlick.contentWidth - hourlyFlick.width, hourlyFlick.contentX - w.angleDelta.y));
					}
				}

				Item {
					width: hourlyFlick.contentWidth
					height: hourlyFlick.height

					// Temperature spline curve with gradient area
					Canvas {
						id: chartCanvas
						anchors.fill: parent
						antialiasing: true

						Connections {
							target: Weather
							function onHourlyForecastChanged() {
								chartCanvas.requestPaint();
							}
						}

						onPaint: {
							var ctx = getContext("2d");
							ctx.reset();
							var list = Weather.hourlyForecast;
							if (!list || list.length < 2)
								return;

							var colW = 54;
							var minT = 999;
							var maxT = -999;
							for (var i = 0; i < list.length; i++) {
								var t = list[i].temp;
								if (t < minT) minT = t;
								if (t > maxT) maxT = t;
							}
							var range = Math.max(3, maxT - minT);
							var yTop = 78;
							var hChart = 50;
							var bottomY = 132;

							var pts = [];
							for (var i = 0; i < list.length; i++) {
								var x = i * colW + colW / 2;
								var y = yTop + (maxT - list[i].temp) / range * hChart;
								pts.push({ x: x, y: y });
							}

								// Gradient fill under the curve
								ctx.beginPath();
								ctx.moveTo(pts[0].x, bottomY);
								ctx.lineTo(pts[0].x, pts[0].y);
								for (var i = 0; i < pts.length - 1; i++) {
									var p0 = pts[i];
									var p1 = pts[i + 1];
									var cx = (p0.x + p1.x) / 2;
									ctx.bezierCurveTo(cx, p0.y, cx, p1.y, p1.x, p1.y);
								}
								ctx.lineTo(pts[pts.length - 1].x, bottomY);
								ctx.closePath();

								var grad = ctx.createLinearGradient(0, yTop, 0, bottomY);
								var ac = Theme.accent;
								var r255 = Math.round(ac.r * 255), g255 = Math.round(ac.g * 255), b255 = Math.round(ac.b * 255);
								grad.addColorStop(0, "rgba(" + r255 + ", " + g255 + ", " + b255 + ", 0.35)");
								grad.addColorStop(1, "rgba(" + r255 + ", " + g255 + ", " + b255 + ", 0.0)");
								ctx.fillStyle = grad;
								ctx.fill();

								// Smooth curve stroke
								ctx.beginPath();
								ctx.moveTo(pts[0].x, pts[0].y);
								for (var i = 0; i < pts.length - 1; i++) {
									var p0 = pts[i];
									var p1 = pts[i + 1];
									var cx = (p0.x + p1.x) / 2;
									ctx.bezierCurveTo(cx, p0.y, cx, p1.y, p1.x, p1.y);
								}
								ctx.strokeStyle = Theme.accentBlue;
								ctx.lineWidth = 2.5;
								ctx.stroke();

								// Donut dots on points
								for (var i = 0; i < pts.length; i++) {
									ctx.beginPath();
									ctx.arc(pts[i].x, pts[i].y, 4, 0, 2 * Math.PI);
									ctx.fillStyle = Theme.accentBlue;
									ctx.fill();
									ctx.beginPath();
									ctx.arc(pts[i].x, pts[i].y, 2, 0, 2 * Math.PI);
									ctx.fillStyle = Theme.bgCard;
									ctx.fill();
								}
							}
						}

						// Text & Icon items positioned over each hour column
						Repeater {
							model: Weather.hourlyForecast

							Item {
								required property var modelData
								required property int index

								readonly property real colW: 54
								readonly property real xCenter: index * colW + colW / 2
								readonly property var stats: {
									var list = Weather.hourlyForecast || [];
									var minT = 999, maxT = -999;
									for (var i = 0; i < list.length; i++) {
										if (list[i].temp < minT) minT = list[i].temp;
										if (list[i].temp > maxT) maxT = list[i].temp;
									}
									return { minT: minT, maxT: maxT, range: Math.max(3, maxT - minT) };
								}
								readonly property real pointY: 78 + (stats.maxT - modelData.temp) / stats.range * 50

								x: index * colW
								y: 0
								width: colW
								height: parent.height

								// Time (Now / 21:00 / ...)
								Text {
									anchors.horizontalCenter: parent.horizontalCenter
									y: 2
									text: modelData.time
									font.family: Theme.fontFamily
									font.pixelSize: 13
									font.bold: index === 0
									color: index === 0 ? Theme.accentBlue : Theme.textDim
								}

								// Weather condition glyph
								Text {
									anchors.horizontalCenter: parent.horizontalCenter
									y: 21
									text: modelData.icon
									font.family: Theme.fontFamily
									font.pixelSize: 19
									color: Theme.textMain
								}

								// Temperature centered directly above the curve point
								Item {
									anchors.horizontalCenter: parent.horizontalCenter
									y: pointY - tempNum.implicitHeight - 6
									width: tempNum.implicitWidth
									height: tempNum.implicitHeight

									Text {
										id: tempNum
										anchors.centerIn: parent
										text: modelData.temp
										font.family: Theme.fontFamily
										font.pixelSize: 15
										font.bold: true
										color: Theme.textMain
									}

									Text {
										anchors.left: tempNum.right
										anchors.top: tempNum.top
										anchors.topMargin: -1
										text: "°"
										font.family: Theme.fontFamily
										font.pixelSize: 12
										font.bold: true
										color: Theme.textDim
									}
								}

								// Rain probability if >= 10%
								Row {
									visible: modelData.pop >= 10
									anchors.horizontalCenter: parent.horizontalCenter
									y: 138
									spacing: 2

									Text {
										text: "󰖗"
										font.family: Theme.fontFamily
										font.pixelSize: 11
										color: Theme.accentBlue
										anchors.verticalCenter: parent.verticalCenter
									}
									Text {
										text: modelData.pop + "%"
										font.family: Theme.fontFamily
										font.pixelSize: 11
										color: Theme.accentBlue
										anchors.verticalCenter: parent.verticalCenter
									}
								}
							}
						}
					}
				}

			// ─── Divider ───────────────────────────────────────────────────────
			Rectangle {
				visible: Weather.forecastDays.length > 0
				width: parent.width
				height: 1
				color: Theme.border
			}

			// ─── 3-Day Forecast Row ───────────────────────────────────────────
			Item {
				visible: Weather.forecastDays.length > 0
				width: parent.width
				height: forecastRow.height

				Row {
					id: forecastRow
					anchors.horizontalCenter: parent.horizontalCenter
					spacing: 36

					Repeater {
						model: Weather.forecastDays

						Row {
							required property var modelData
							required property int index
							spacing: 10

							Text {
								anchors.verticalCenter: parent.verticalCenter
								text: Weather.dayIcon(modelData)
								color: Theme.accentBlue
								font.family: Theme.fontFamily
								font.pixelSize: 30
							}

							Column {
								anchors.verticalCenter: parent.verticalCenter
								spacing: 3

								Text {
									text: WeatherModel.dayName(modelData.date, null).toUpperCase()
									color: Theme.textDim
									font.family: Theme.fontFamily
									font.pixelSize: 14
									font.letterSpacing: 1
								}

								Row {
									spacing: 6

									Text {
										text: Weather.bareTempForDay(modelData, "max")
										color: Theme.textMain
										font.family: Theme.fontFamily
										font.pixelSize: 15
										font.bold: true
									}

									Text {
										text: Weather.bareTempForDay(modelData, "min")
										color: Theme.textMuted
										font.family: Theme.fontFamily
										font.pixelSize: 15
									}
								}
							}
						}
					}
				}
			}
		}
	}
}
