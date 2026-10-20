import ".."
import "../widgets"
import "../WeatherModel.js" as WeatherModel
import QtQuick
import QtQuick.Layouts

OverlayWindow {
	id: root

	panel: "weather"
	style: "slide"
	card: weatherCard
	offscreenSlide: Math.max(700, weatherCard.height + Theme.notifTopMargin + 60)

	function requestDismiss() {
		if (Weather.editingLocation)
			Weather.cancelEditingLocation();
		else
			Panels.close("weather");
	}

	onDismissRequested: root.requestDismiss()
	onOpened: {
		Weather.refresh();
		chartCanvas.requestPaint();
		weatherCard.forceActiveFocus();
	}
	onShownChanged: {
		if (!shown && Weather.editingLocation)
			Weather.cancelEditingLocation();
	}

	Connections {
		target: Weather
		function onEditingLocationChanged() {
			if (!Weather.editingLocation)
				weatherCard.forceActiveFocus();
		}
	}

	Rectangle {
		id: weatherCard
		anchors.horizontalCenter: parent.horizontalCenter
		y: Theme.notifTopMargin - root.slide
		width: Math.min(576, root.width - 32)
		height: weatherCol.implicitHeight + Theme.paddingCard * 2
		color: Theme.glass(Theme.bgCard)
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

		Keys.onPressed: event => {
			if (event.key === Qt.Key_E && !Weather.editingLocation) {
				Weather.startEditingLocation();
				event.accepted = true;
			}
		}

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

			Item {
				width: parent.width
				height: Math.max(heroLeft.implicitHeight, heroRight.implicitHeight)

				Row {
					id: heroLeft
					anchors.left: parent.left
					anchors.verticalCenter: parent.verticalCenter
					spacing: 14

					LineIcon {
						id: heroIcon
						anchors.verticalCenter: parent.verticalCenter
						name: Weather.current?.icon ?? ""
						color: Theme.textMain
						size: 58
					}

					Column {
						anchors.verticalCenter: parent.verticalCenter
						spacing: 2

						Row {
							spacing: 2

							StyledText {
								id: tempBig
								text: Weather.current?.tempNum ?? "—"
								font.pixelSize: 48
								font.bold: true
							}

							StyledText {
								text: Weather.current ? "°C" : ""
								color: Theme.textDim
								font.pixelSize: Theme.fontSizeLarge
								anchors.top: tempBig.top
								anchors.topMargin: 6
							}
						}

						Row {
							spacing: 6
							visible: !!(Weather.today.high || Weather.today.low)

							StyledText {
								text: "↑" + (Weather.today.high || "—")
								font.pixelSize: Theme.fontSizeSmall
								font.bold: true
							}

							StyledText {
								text: "↓" + (Weather.today.low || "—")
								color: Theme.textMuted
								font.pixelSize: Theme.fontSizeSmall
								font.bold: true
							}
						}
					}
				}

				Column {
					id: heroRight
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					spacing: 8

					Item {
						anchors.right: parent.right
						visible: !Weather.editingLocation
						width: locRow.implicitWidth
						height: locRow.implicitHeight

						Row {
							id: locRow
							spacing: 6

							LineIcon {
								name: "map-pin"
								color: Theme.accentBlue
								size: Theme.fontSizeSmall
								anchors.verticalCenter: parent.verticalCenter
							}

							StyledText {
								text: (Weather.reportLocation || "SET LOCATION").toUpperCase()
								color: locationArea.containsMouse ? Theme.textMain : Theme.textDim
								font.pixelSize: Theme.fontSizeSmall
								font.bold: true
								font.letterSpacing: 1
								anchors.verticalCenter: parent.verticalCenter
							}

							LineIcon {
								name: "pencil"
								color: locationArea.containsMouse ? Theme.accentBlue : Theme.textMuted
								size: 12
								anchors.verticalCenter: parent.verticalCenter
							}

							HotkeyHint {
								key: "E"
								lit: locationArea.containsMouse
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

						Rectangle {
							width: 32
							height: 32
							color: clearArea.containsMouse ? Theme.bgHover : "transparent"
							border.color: Theme.border
							border.width: 1
							radius: Theme.roundingElement

							LineIcon {
								anchors.centerIn: parent
								name: Weather.savingLocation ? "loader-circle" : "x"
								color: Theme.textDim
								size: Theme.fontSizeSmall

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

					Row {
						id: weatherStats
						anchors.right: parent.right
						visible: !!Weather.current
						spacing: 20

						Repeater {
							model: [
								{ label: "FEELS", value: Weather.current?.feelsLike },
								{ label: "WIND", value: Weather.current?.wind },
								{ label: "HUMID", value: Weather.current?.humidity }
							]

							Column {
								required property var modelData
								spacing: 3

								StyledText {
									text: modelData.label
									color: Theme.textMuted
									font.pixelSize: Theme.fontSizeTiny
									font.letterSpacing: 1
								}
								StyledText {
									text: modelData.value ?? ""
									font.bold: true
								}
							}
						}
					}
				}
			}

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
						color: "transparent"

						SelectionHighlight {
							selected: index === Weather.suggestionIndex
						}

						Row {
							anchors.fill: parent
							anchors.leftMargin: 12
							anchors.rightMargin: 12
							spacing: 8

							StyledText {
								anchors.verticalCenter: parent.verticalCenter
								text: modelData ? modelData.name : ""
								font.pixelSize: Theme.fontSizeSmall
								font.bold: true
							}

							StyledText {
								anchors.verticalCenter: parent.verticalCenter
								visible: !!(modelData && modelData.description)
								text: modelData && modelData.description ? modelData.description : ""
								color: Theme.textDim
								font.pixelSize: Theme.fontSizeTiny
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

			ColumnLayout {
				visible: !Weather.current
				width: parent.width
				spacing: 6

				StyledText {
					Layout.alignment: Qt.AlignHCenter
					text: Weather.lastError !== "" ? Weather.lastError : "Fetching weather..."
					color: Weather.lastError !== "" ? Theme.critical : Theme.textDim
					font.pixelSize: Theme.fontSizeSmall
					font.italic: Weather.lastError === ""
				}

				TextButton {
					visible: Weather.lastError !== ""
					Layout.alignment: Qt.AlignHCenter
					text: "Retry"
					onClicked: Weather.refresh()
				}
			}

			Rectangle {
				visible: Weather.hourlyForecast && Weather.hourlyForecast.length > 0
				width: parent.width
				height: 1
				color: Theme.border
			}

			Flickable {
				id: hourlyFlick
				visible: Weather.hourlyForecast && Weather.hourlyForecast.length > 0
				width: parent.width
				height: 164
				contentWidth: Math.max(width, (Weather.hourlyForecast?.length ?? 0) * columnWidth)
				contentHeight: height
				flickableDirection: Flickable.HorizontalFlick
				clip: true

				// One column per hour; the curve runs between chartTop and
				// chartTop + chartHeight, its fill down to chartBottom.
				readonly property int columnWidth: 54
				readonly property int chartTop: 78
				readonly property int chartHeight: 50
				readonly property int chartBottom: 132
				readonly property var points: WeatherModel.chartPoints(Weather.hourlyForecast, columnWidth, chartTop, chartHeight)

				onPointsChanged: chartCanvas.requestPaint()

				WheelScroll {
					flickable: hourlyFlick
					horizontal: true
				}

				Item {
					width: hourlyFlick.contentWidth
					height: hourlyFlick.height

					Canvas {
						id: chartCanvas
						anchors.fill: parent
						antialiasing: true

						function traceCurve(ctx, pts) {
							for (var i = 0; i < pts.length - 1; i++) {
								var cx = (pts[i].x + pts[i + 1].x) / 2;
								ctx.bezierCurveTo(cx, pts[i].y, cx, pts[i + 1].y, pts[i + 1].x, pts[i + 1].y);
							}
						}

						onPaint: {
							var ctx = getContext("2d");
							ctx.reset();
							var pts = hourlyFlick.points;
							if (pts.length < 2)
								return;
							var last = pts[pts.length - 1];

							ctx.beginPath();
							ctx.moveTo(pts[0].x, hourlyFlick.chartBottom);
							ctx.lineTo(pts[0].x, pts[0].y);
							traceCurve(ctx, pts);
							ctx.lineTo(last.x, hourlyFlick.chartBottom);
							ctx.closePath();
							var grad = ctx.createLinearGradient(0, hourlyFlick.chartTop, 0, hourlyFlick.chartBottom);
							grad.addColorStop(0, Theme.alpha(Theme.accent, 0.35));
							grad.addColorStop(1, Theme.alpha(Theme.accent, 0));
							ctx.fillStyle = grad;
							ctx.fill();

							ctx.beginPath();
							ctx.moveTo(pts[0].x, pts[0].y);
							traceCurve(ctx, pts);
							ctx.strokeStyle = Theme.accentBlue;
							ctx.lineWidth = 2.5;
							ctx.stroke();

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

					Repeater {
						model: Weather.hourlyForecast

						Item {
							required property var modelData
							required property int index

							x: index * hourlyFlick.columnWidth
							y: 0
							width: hourlyFlick.columnWidth
							height: parent.height

							StyledText {
								anchors.horizontalCenter: parent.horizontalCenter
								y: 2
								text: modelData.time
								font.pixelSize: Theme.fontSizeTiny
								font.bold: index === 0
								color: index === 0 ? Theme.accentBlue : Theme.textDim
							}

							LineIcon {
								anchors.horizontalCenter: parent.horizontalCenter
								y: 21
								name: modelData.icon
								size: 19
								color: Theme.textMain
							}

							Item {
								anchors.horizontalCenter: parent.horizontalCenter
								y: (hourlyFlick.points[index]?.y ?? 0) - tempNum.implicitHeight - 6
								width: tempNum.implicitWidth
								height: tempNum.implicitHeight

								StyledText {
									id: tempNum
									anchors.centerIn: parent
									text: modelData.temp
									font.bold: true
								}

								StyledText {
									anchors.left: tempNum.right
									anchors.top: tempNum.top
									anchors.topMargin: -1
									text: "°"
									font.pixelSize: Theme.fontSizeTiny
									font.bold: true
									color: Theme.textDim
								}
							}

							Row {
								visible: modelData.pop >= 10
								anchors.horizontalCenter: parent.horizontalCenter
								y: 138
								spacing: 2

								LineIcon {
									name: "droplet"
									size: 11
									color: Theme.accentBlue
									anchors.verticalCenter: parent.verticalCenter
								}
								StyledText {
									text: modelData.pop + "%"
									font.pixelSize: Theme.fontSizeTiny
									color: Theme.accentBlue
									anchors.verticalCenter: parent.verticalCenter
								}
							}
						}
					}
				}
			}

			Rectangle {
				visible: Weather.forecastDays.length > 0
				width: parent.width
				height: 1
				color: Theme.border
			}

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

							LineIcon {
								anchors.verticalCenter: parent.verticalCenter
								name: modelData.icon
								color: Theme.accentBlue
								size: 30
							}

							Column {
								anchors.verticalCenter: parent.verticalCenter
								spacing: 3

								StyledText {
									text: modelData.dayName.toUpperCase()
									color: Theme.textDim
									font.pixelSize: Theme.fontSizeSmall
									font.letterSpacing: 1
								}

								Row {
									spacing: 6

									StyledText {
										text: modelData.maxTemp
										font.bold: true
									}

									StyledText {
										text: modelData.minTemp
										color: Theme.textMuted
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
