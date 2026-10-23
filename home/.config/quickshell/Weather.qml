pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "WeatherModel.js" as WeatherModel

// The forecast from Open-Meteo, every quarter of an hour: for the place in
// ~/.config/weather.json ({ "name", "latitude", "longitude" }), or else for
// where ipwho.is places this IP address.
Singleton {
	id: root

	// parseOpenMeteoCurrent's fields; null until the first forecast arrives.
	property var current: null
	property var today: ({ high: "", low: "" })
	property var hourlyForecast: []
	property var forecastDays: []
	// Where the forecast is for.
	property string location: ""
	// What went wrong, while there is no forecast to show instead.
	property string lastError: ""

	readonly property string tooltipText: {
		if (!current)
			return location || "Weather";
		// The bar shows the temperature already; the panel has the rest.
		var range = today.high && today.low ? "↑" + today.high + " ↓" + today.low : "";
		return [location, range].filter(p => p).join(" · ") || "Weather";
	}

	function refresh(): void {
		placeFile.reload();
		var place = WeatherModel.parseLocationFile(placeFile.text());
		if (place.latitude !== null) {
			location = place.name;
			fetchForecast(place.latitude, place.longitude);
		} else if (!ipProc.running) {
			ipProc.running = true;
		}
	}

	// Without a forecast yet (offline at login, a slow answer) the bar has
	// nothing to show, so it tries again soon rather than in a quarter hour.
	function fail(message: string): void {
		if (!current) {
			lastError = message;
			retryTimer.restart();
		}
	}

	// One at a time: a refresh asked for meanwhile gets the same forecast.
	function fetchForecast(latitude: real, longitude: real): void {
		if (forecastProc.running)
			return;
		forecastProc.command = ["curl", "-fsS", "--max-time", "6", "https://api.open-meteo.com/v1/forecast"
			+ "?latitude=" + latitude
			+ "&longitude=" + longitude
			+ "&daily=weather_code,temperature_2m_max,temperature_2m_min"
			+ "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
			+ "&hourly=temperature_2m,precipitation_probability,weather_code,is_day"
			+ "&forecast_hours=27"
			+ "&forecast_days=4"
			+ "&timezone=auto"];
		forecastProc.running = true;
	}

	Component.onCompleted: refresh()

	FileView {
		id: placeFile
		path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/weather.json"
		blockLoading: true
		printErrors: false
	}

	Process {
		id: ipProc
		// ipwho.is answers 200 with success=false when it cannot place the address.
		command: ["curl", "-fsS", "--max-time", "4", "https://ipwho.is/?fields=success,city,latitude,longitude"]
		onExited: code => {
			if (code !== 0)
				root.fail("Offline — couldn't detect location");
		}
		stdout: StdioCollector {
			onStreamFinished: {
				if (this.text.trim() === "")
					return;
				try {
					var found = JSON.parse(this.text);
					if (found.success && typeof found.latitude === "number" && typeof found.longitude === "number") {
						root.location = found.city || "";
						root.fetchForecast(found.latitude, found.longitude);
					} else {
						root.fail("Couldn't detect location");
					}
				} catch (e) {
					root.fail("Couldn't detect location");
				}
			}
		}
	}

	Process {
		id: forecastProc
		onExited: code => {
			if (code !== 0)
				root.fail("Offline — couldn't fetch forecast");
		}
		stdout: StdioCollector {
			onStreamFinished: {
				if (this.text.trim() === "")
					return;
				try {
					var report = JSON.parse(this.text);
					root.current = WeatherModel.parseOpenMeteoCurrent(report);
					root.hourlyForecast = WeatherModel.parseOpenMeteoHourly(report);
					root.forecastDays = WeatherModel.parseOpenMeteoDaily(report, Qt.formatDate(new Date(), "yyyy-MM-dd"));
					root.today = WeatherModel.parseTodayHighLow(report);
					root.lastError = "";
				} catch (e) {
					root.fail("Couldn't read the forecast");
				}
			}
		}
	}

	Timer {
		id: retryTimer
		interval: 30 * 1000
		onTriggered: root.refresh()
	}

	Timer {
		interval: 15 * 60 * 1000
		running: true
		repeat: true
		onTriggered: root.refresh()
	}
}
