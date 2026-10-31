import ".."
import "../widgets"
import "../WeatherModel.js" as WeatherModel
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Drawer {
	id: root

	name: "weather"
	cardWidth: Math.min(576, width - 32)
	contentHeight: weatherCol.implicitHeight

	onOpened: {
		Weather.refresh();
		chartCanvas.requestPaint();
		hourlyFlick.contentX = 0;
		root.forceActiveFocus();
	}

	// H / L or the arrows page the hours.
	Keys.onPressed: event => {
		if (event.key === Qt.Key_H || event.key === Qt.Key_Left)
			hourly.page(-1);
		else if (event.key === Qt.Key_L || event.key === Qt.Key_Right)
			hourly.page(1);
	}

	Column {
		id: weatherCol
		anchors.left: parent.left
		anchors.right: parent.right
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
							color: Theme.textDim
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

				Row {
					anchors.right: parent.right
					spacing: 6

					LineIcon {
						visible: Weather.location !== ""
						name: "map-pin"
						color: Theme.accentBlue
						size: Theme.fontSizeSmall
						anchors.verticalCenter: parent.verticalCenter
					}

					StyledText {
						text: Weather.location.toUpperCase()
						color: Theme.textDim
						font.pixelSize: Theme.fontSizeSmall
						font.bold: true
						font.letterSpacing: 1
						anchors.verticalCenter: parent.verticalCenter
					}

					CloseButton {
						anchors.verticalCenter: parent.verticalCenter
						onClicked: Panels.close("weather")
					}
				}

				Row {
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
								color: Theme.textDim
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

		ColumnLayout {
			visible: !Weather.current
			width: parent.width
			spacing: 6

			StyledText {
				Layout.alignment: Qt.AlignHCenter
				text: Weather.lastError !== "" ? Weather.lastError : "Fetching weather…"
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

		Item {
			id: hourly

			readonly property bool moreLeft: hourlyFlick.contentX > 1
			readonly property bool moreRight: hourlyFlick.contentX < hourlyFlick.contentWidth - hourlyFlick.width - 1

			visible: Weather.hourlyForecast && Weather.hourlyForecast.length > 0
			width: parent.width
			height: 164

			function page(direction: int): void {
				hourlyPage.to = Math.max(0, Math.min(hourlyFlick.contentWidth - hourlyFlick.width, hourlyFlick.contentX + direction * hourlyFlick.width * 0.8));
				hourlyPage.restart();
			}

			NumberAnimation {
				id: hourlyPage
				target: hourlyFlick
				property: "contentX"
				duration: Theme.animNormal
				easing.type: Easing.BezierSpline
				easing.bezierCurve: Theme.easeOutQuint
			}

			Flickable {
				id: hourlyFlick
				anchors.fill: parent
				contentWidth: Math.max(width, (Weather.hourlyForecast?.length ?? 0) * columnWidth)
				contentHeight: height
				flickableDirection: Flickable.HorizontalFlick
				clip: true
				layer.enabled: true
				layer.effect: MultiEffect {
					maskEnabled: true
					maskSource: hourlyFade
					maskThresholdMin: 0
					maskSpreadAtMin: 1
				}

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
							grad.addColorStop(0, Theme.alpha(Theme.accentBlue, 0.35));
							grad.addColorStop(1, Theme.alpha(Theme.accentBlue, 0));
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

			// The hours fade out on a side with more of them, a chevron there pages on.
			Item {
				id: hourlyFade
				anchors.fill: parent
				visible: false
				layer.enabled: true

				Rectangle {
					anchors.fill: parent
					gradient: Gradient {
						orientation: Gradient.Horizontal
						GradientStop { position: 0; color: hourly.moreLeft ? "transparent" : "white" }
						GradientStop { position: 0.1; color: "white" }
						GradientStop { position: 0.9; color: "white" }
						GradientStop { position: 1; color: hourly.moreRight ? "transparent" : "white" }
					}
				}
			}

			Repeater {
				model: [{ side: -1, icon: "chevron-left" }, { side: 1, icon: "chevron-right" }]

				delegate: IconButton {
					required property var modelData
					readonly property bool more: modelData.side < 0 ? hourly.moreLeft : hourly.moreRight

					x: modelData.side < 0 ? 0 : hourly.width - width
					y: 10
					implicitWidth: 24
					implicitHeight: 24
					icon: modelData.icon
					outlined: false
					opacity: more ? 1 : 0
					visible: opacity > 0
					onClicked: hourly.page(modelData.side)

					Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
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
									color: Theme.textDim
								}
							}
						}
					}
				}
			}
		}
	}
}
