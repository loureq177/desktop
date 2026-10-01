// Weather state singleton: fetches conditions from Open-Meteo & wttr.in,
// manages location persistence, and coordinates the weather popup panel.
// Control via IPC: `qs ipc call weather <toggle|open|close|refresh>`
// (SUPER + W).
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "WeatherModel.js" as WeatherModel

Singleton {
	id: root

	property bool panelOpen: false

	// Parsed wttr.in and Open-Meteo responses.
	property var report: null
	property var dailyForecastReport: null
	property string wttrLocation: ""

	// Configured location state from weather.json
	property var configuredLocationState: ({ name: "", latitude: null, longitude: null })
	readonly property string configuredLocation: configuredLocationState.name
	readonly property string locationQuery: WeatherModel.wttrLocationQuery(configuredLocationState.name, configuredLocationState.latitude, configuredLocationState.longitude)

	onLocationQueryChanged: {
		if (savingLocation)
			savingLocationQueryStarted = true;
		forecastRetries = 0;
		dailyForecastRetries = 0;
		forecastProc.running = false;
		dailyForecastProc.running = false;
		Qt.callLater(refresh);
	}

	FileView {
		id: locationFile
		path: Quickshell.env("HOME") + "/.local/state/weather/weather.json"
		watchChanges: true
		printErrors: false
		onFileChanged: reload()
		onLoaded: {
			root.configuredLocationState = WeatherModel.parseLocationFile(this.text());
		}
		onLoadFailed: {
			root.configuredLocationState = WeatherModel.parseLocationFile("");
		}
	}

	Timer {
		interval: 1500
		running: true
		onTriggered: {
			locationFile.reload();
		}
	}

	property int forecastRetries: 0
	property int dailyForecastRetries: 0

	// Click-to-edit state for the location label
	property bool editingLocation: false
	property bool savingLocation: false
	property bool savingLocationQueryStarted: false
	property var locationSuggestions: []
	property int suggestionIndex: 0
	property string geocodePendingQuery: ""
	property string geocodeActiveQuery: ""

	// Current weather icon for pill & hero view
	property string label: ""

	readonly property bool hasConfiguredCoordinates: !isNaN(parseFloat(String(configuredLocationState.latitude))) && !isNaN(parseFloat(String(configuredLocationState.longitude)))
	readonly property var openMeteoCurrent: WeatherModel.openMeteoCurrentCondition(dailyForecastReport)
	readonly property var current: (hasConfiguredCoordinates && openMeteoCurrent) ? openMeteoCurrent : ((report && report.current_condition && report.current_condition[0]) ? report.current_condition[0] : openMeteoCurrent)
	readonly property var areaInfo: report && report.nearest_area && report.nearest_area[0] ? report.nearest_area[0] : null
	readonly property var forecastDays: WeatherModel.buildForecastDays(report, dailyForecastReport, Qt.formatDate(new Date(), "yyyy-MM-dd"))
	readonly property var hourlyForecast: WeatherModel.buildHourlyForecast(report, dailyForecastReport, useImperial)
	readonly property string reportCountry: areaInfo && areaInfo.country && areaInfo.country[0] ? areaInfo.country[0].value : ""

	readonly property bool useImperial: WeatherModel.shouldUseImperial("", Qt.locale().name, reportCountry)
	readonly property int refreshMinutes: 15

	readonly property string reportLocation: configuredLocation || wttrLocation || (areaInfo && areaInfo.areaName && areaInfo.areaName[0] ? areaInfo.areaName[0].value : "")
	readonly property string tempNum: current ? String(useImperial ? current.temp_F : current.temp_C) : ""
	readonly property string tempUnit: "°" + (useImperial ? "F" : "C")
	readonly property string reportFeels: current ? WeatherModel.formatTemp(useImperial ? current.FeelsLikeF : current.FeelsLikeC, useImperial) : ""
	readonly property string reportWind: current ? (useImperial ? (current.windspeedMiles + " mph") : (current.windspeedKmph + " km/h")) : ""
	readonly property string reportHumidity: current ? (current.humidity + "%") : ""

	readonly property string tooltipText: {
		if (!reportLocation && !tempNum)
			return "Weather";
		var s = (reportLocation ? reportLocation + ": " : "") + (tempNum ? tempNum + tempUnit : "");
		if (reportFeels)
			s += ", Feels like " + reportFeels;
		if (reportWind)
			s += " · Wind " + reportWind;
		return s;
	}

	function toggle() {
		if (root.panelOpen)
			close();
		else
			open();
	}

	function open() {
		root.panelOpen = true;
		locationFile.reload();
		root.refresh();
	}

	function close() {
		root.panelOpen = false;
		if (root.editingLocation)
			cancelEditingLocation();
	}

	function refresh() {
		forecastRetries = 0;
		dailyForecastRetries = 0;
		forecastProc.command = ["curl", "-fsS", "--max-time", "10", "https://wttr.in/" + root.locationQuery + "?format=j1"];
		if (!forecastProc.running)
			forecastProc.running = true;
		if (root.locationQuery === "" && !locationProc.running)
			locationProc.running = true;
		refreshDailyForecast(null);
	}

	function refreshDailyForecast(sourceReport) {
		if (dailyForecastProc.running)
			return;

		var lat = parseFloat(String(root.configuredLocationState.latitude));
		var lon = parseFloat(String(root.configuredLocationState.longitude));
		if (isNaN(lat) || isNaN(lon)) {
			var area = sourceReport && sourceReport.nearest_area && sourceReport.nearest_area[0] ? sourceReport.nearest_area[0] : root.areaInfo;
			if (!area)
				return;
			lat = parseFloat(String(area.latitude || ""));
			lon = parseFloat(String(area.longitude || ""));
		}
		if (isNaN(lat) || isNaN(lon))
			return;

		var url = "https://api.open-meteo.com/v1/forecast"
			+ "?latitude=" + encodeURIComponent(String(lat))
			+ "&longitude=" + encodeURIComponent(String(lon))
			+ "&daily=weather_code,temperature_2m_max,temperature_2m_min"
			+ "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
			+ "&hourly=temperature_2m,precipitation_probability,weather_code,is_day"
			+ "&forecast_hours=24"
			+ "&forecast_days=4"
			+ "&timezone=auto";
		dailyForecastProc.command = ["curl", "-fsS", "--max-time", "5", url];
		dailyForecastProc.running = true;
	}

	function startEditingLocation() {
		editingLocation = true;
		savingLocation = false;
		savingLocationQueryStarted = false;
		locationSuggestions = [];
		suggestionIndex = 0;
	}

	function cancelEditingLocation() {
		editingLocation = false;
		savingLocation = false;
		savingLocationQueryStarted = false;
		locationSuggestions = [];
		geocodeDebounce.stop();
	}

	function commitLocation(text) {
		var location = WeatherModel.locationCommit(text, locationSuggestions, suggestionIndex);
		if (location.name === "") {
			clearLocation();
			return;
		}
		savingLocation = true;
		savingLocationQueryStarted = false;
		configuredLocationState = {
			name: location.name,
			latitude: location.latitude,
			longitude: location.longitude
		};
		persistLocation(location.name, location.latitude, location.longitude);
	}

	function clearLocation() {
		persistLocation("", null, null);
		wttrLocation = "";
		cancelEditingLocation();
	}

	function pickSuggestion(suggestion) {
		if (!suggestion)
			return;
		savingLocation = true;
		savingLocationQueryStarted = false;
		configuredLocationState = {
			name: suggestion.name,
			latitude: suggestion.latitude,
			longitude: suggestion.longitude
		};
		persistLocation(suggestion.name, suggestion.latitude, suggestion.longitude);
	}

	function finishSavingLocation() {
		if (savingLocation && savingLocationQueryStarted)
			cancelEditingLocation();
	}

	function persistLocation(name, latitude, longitude) {
		if (name && latitude !== null && longitude !== null)
			locationSaveProc.command = ["weather-location", "--set", name, latitude + "," + longitude];
		else if (name)
			locationSaveProc.command = ["weather-location", "--set", name];
		else
			locationSaveProc.command = ["weather-location", "--clear"];
		locationSaveProc.running = true;
	}

	function requestGeocode(query) {
		var q = String(query || "").trim();
		if (q.length < 2) {
			geocodeDebounce.stop();
			geocodePendingQuery = "";
			locationSuggestions = [];
			return;
		}
		geocodePendingQuery = q;
		geocodeDebounce.restart();
	}

	function startGeocode() {
		if (geocodePendingQuery === "" || !editingLocation)
			return;
		geocodeActiveQuery = geocodePendingQuery;
		geocodeProc.running = false;
		geocodeProc.command = [
			"curl", "-fsS", "--max-time", "5",
			"https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(geocodeActiveQuery) + "&count=5&language=en&format=json"
		];
		geocodeProc.running = true;
	}

	function bareTempForDay(day, kind) {
		return WeatherModel.bareTempForDay(day, kind, useImperial);
	}

	function dayIcon(day) {
		return WeatherModel.dayIcon(day);
	}

	function status(): string {
		if (!reportLocation && !tempNum)
			return "Weather unavailable";
		var s = (reportLocation ? reportLocation : "") + "  ·  Temp " + tempNum + tempUnit;
		if (reportWind)
			s += "  ·  Wind " + reportWind;
		return s;
	}

	// ─── Processes ────────────────────────────────────────────────────────

	Process {
		id: forecastProc
		command: ["curl", "-fsS", "--max-time", "10", "https://wttr.in/" + root.locationQuery + "?format=j1"]
		stdout: StdioCollector {
			waitForEnd: true
			onStreamFinished: {
				var raw = String(text || "").trim();
				if (!raw) {
					root.scheduleForecastRetry();
					return;
				}
				try {
					var parsed = JSON.parse(raw);
					root.report = parsed;
					if (!root.hasConfiguredCoordinates)
						root.label = WeatherModel.provisionalCurrentIcon(parsed.current_condition && parsed.current_condition[0], root.label);
					root.forecastRetries = 0;
					if (WeatherModel.weatherResponseCompletesSave(root.hasConfiguredCoordinates, "wttr"))
						root.finishSavingLocation();
					if (isNaN(parseFloat(String(root.configuredLocationState.latitude))))
						root.refreshDailyForecast(parsed);
				} catch (e) {
					root.scheduleForecastRetry();
				}
			}
		}
	}

	function scheduleForecastRetry(): void {
		if (forecastRetries >= 3)
			return;
		forecastRetries++;
		forecastRetryTimer.restart();
	}

	Timer {
		id: forecastRetryTimer
		interval: 2500
		onTriggered: if (!forecastProc.running) forecastProc.running = true
	}

	function scheduleDailyForecastRetry(): void {
		if (dailyForecastRetries >= 3)
			return;
		dailyForecastRetries++;
		dailyForecastRetryTimer.restart();
	}

	Timer {
		id: dailyForecastRetryTimer
		interval: 2500
		onTriggered: root.refreshDailyForecast(null)
	}

	Process {
		id: dailyForecastProc
		stdout: StdioCollector {
			waitForEnd: true
			onStreamFinished: {
				var raw = String(text || "").trim();
				if (!raw) {
					root.scheduleDailyForecastRetry();
					return;
				}
				try {
					var parsed = JSON.parse(raw);
					var parsedCurrent = WeatherModel.openMeteoCurrentCondition(parsed);
					root.dailyForecastReport = parsed;
					root.label = WeatherModel.currentIcon(parsedCurrent, root.label);
					root.dailyForecastRetries = 0;
					if (WeatherModel.weatherResponseCompletesSave(root.hasConfiguredCoordinates, "open-meteo"))
						root.finishSavingLocation();
				} catch (e) {
					root.scheduleDailyForecastRetry();
				}
			}
		}
	}

	Process {
		id: geocodeProc
		stdout: StdioCollector {
			waitForEnd: true
			onStreamFinished: {
				root.locationSuggestions = root.editingLocation ? WeatherModel.parseGeocodingResults(text) : [];
				root.suggestionIndex = 0;
				if (root.editingLocation && root.geocodePendingQuery !== "" && root.geocodePendingQuery !== root.geocodeActiveQuery)
					geocodeDebounce.restart();
			}
		}
	}

	Timer {
		id: geocodeDebounce
		interval: 250
		repeat: false
		onTriggered: root.startGeocode()
	}

	Process {
		id: locationSaveProc
		onExited: exitCode => {
			if (exitCode !== 0 || !root.savingLocation)
				return;
			locationFile.reload();
			if (!root.savingLocationQueryStarted) {
				root.savingLocationQueryStarted = true;
				root.forecastRetries = 0;
				root.dailyForecastRetries = 0;
				forecastProc.running = false;
				dailyForecastProc.running = false;
				Qt.callLater(root.refresh);
			}
		}
	}

	Process {
		id: locationProc
		command: ["curl", "-fsS", "--max-time", "4", "https://wttr.in/?format=%l"]
		stdout: StdioCollector {
			waitForEnd: true
			onStreamFinished: {
				var raw = String(text || "").trim();
				if (!raw)
					return;
				root.wttrLocation = raw.split(",")[0].trim();
			}
		}
	}

	Timer {
		id: refreshTimer
		interval: root.refreshMinutes * 60 * 1000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: root.refresh()
	}

	IpcHandler {
		target: "weather"

		function open(): void { root.open() }
		function close(): void { root.close() }
		function toggle(): void { root.toggle() }
		function refresh(): void { root.refresh() }
		function status(): string { return root.status() }
	}
}
