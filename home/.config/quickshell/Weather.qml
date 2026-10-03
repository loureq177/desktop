// Weather state singleton: fetches conditions from Open-Meteo,
// manages location persistence, and coordinates the weather popup panel.
// Control via IPC: `qs ipc call weather <toggle|open|close|refresh|status|icon>`
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "WeatherModel.js" as WeatherModel

Singleton {
	id: root

	property bool panelOpen: false

	// Parsed Open-Meteo response
	property var report: null
	property var current: null
	property var hourlyForecast: []
	property var forecastDays: []

	// IP-detected fallback location
	property string ipCity: ""
	property var ipLat: null
	property var ipLon: null

	// Configured location state from weather.json
	property var configuredLocationState: ({ name: "", latitude: null, longitude: null })
	readonly property string configuredLocation: configuredLocationState.name

	FileView {
		id: locationFile
		path: Quickshell.env("HOME") + "/.local/state/weather/weather.json"
		watchChanges: true
		printErrors: false
		onFileChanged: reload()
		onLoaded: {
			root.configuredLocationState = WeatherModel.parseLocationFile(this.text());
			root.refresh();
		}
		onLoadFailed: {
			root.configuredLocationState = WeatherModel.parseLocationFile("");
			root.refresh();
		}
	}

	// Click-to-edit state for the location label
	property bool editingLocation: false
	property bool savingLocation: false
	property var locationSuggestions: []
	property int suggestionIndex: 0
	property string geocodePendingQuery: ""
	property string geocodeActiveQuery: ""

	// Weather values for bar pill & hero view
	property string label: ""
	property string tempNum: ""
	readonly property string tempUnit: "°C"
	property string reportFeels: ""
	property string reportWind: ""
	property string reportHumidity: ""
	property string reportTodayHigh: ""
	property string reportTodayLow: ""

	readonly property int refreshMinutes: 15

	readonly property string reportLocation: configuredLocation || ipCity || (current ? "Current Location" : "")

	readonly property string tooltipText: {
		if (!reportLocation && !tempNum)
			return "Weather";
		var s = (reportLocation ? reportLocation + ": " : "") + (tempNum ? tempNum + tempUnit : "");
		if (reportTodayHigh && reportTodayLow)
			s += " (↑" + reportTodayHigh + " ↓" + reportTodayLow + ")";
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
		var lat = parseFloat(String(root.configuredLocationState.latitude));
		var lon = parseFloat(String(root.configuredLocationState.longitude));
		if (!isNaN(lat) && !isNaN(lon)) {
			fetchForecast(lat, lon);
		} else {
			if (!ipProc.running)
				ipProc.running = true;
		}
	}

	function fetchForecast(lat, lon) {
		var url = "https://api.open-meteo.com/v1/forecast"
			+ "?latitude=" + encodeURIComponent(String(lat))
			+ "&longitude=" + encodeURIComponent(String(lon))
			+ "&daily=weather_code,temperature_2m_max,temperature_2m_min"
			+ "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
			+ "&hourly=temperature_2m,precipitation_probability,weather_code,is_day"
			+ "&forecast_hours=27"
			+ "&forecast_days=4"
			+ "&timezone=auto";
		forecastProc.command = ["curl", "-fsS", "--max-time", "6", url];
		if (!forecastProc.running)
			forecastProc.running = true;
	}

	function startEditingLocation() {
		editingLocation = true;
		savingLocation = false;
		locationSuggestions = [];
		suggestionIndex = 0;
	}

	function cancelEditingLocation() {
		editingLocation = false;
		savingLocation = false;
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
		configuredLocationState = {
			name: location.name,
			latitude: location.latitude,
			longitude: location.longitude
		};
		persistLocation(location.name, location.latitude, location.longitude);
	}

	function clearLocation() {
		persistLocation("", null, null);
		ipCity = "";
		cancelEditingLocation();
	}

	function pickSuggestion(suggestion) {
		if (!suggestion)
			return;
		savingLocation = true;
		configuredLocationState = {
			name: suggestion.name,
			latitude: suggestion.latitude,
			longitude: suggestion.longitude
		};
		persistLocation(suggestion.name, suggestion.latitude, suggestion.longitude);
	}

	function finishSavingLocation() {
		if (savingLocation)
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
		if (!day) return "";
		return kind === "max" ? day.maxTemp : day.minTemp;
	}

	function dayIcon(day) {
		return day ? day.icon : "";
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
		id: ipProc
		command: ["curl", "-fsS", "--max-time", "4", "https://geolocation-db.com/json/"]
		stdout: StdioCollector {
			waitForEnd: true
			onStreamFinished: {
				var raw = String(text || "").trim();
				if (!raw) return;
				try {
					var parsed = JSON.parse(raw);
					var lat = (parsed.latitude !== undefined ? parsed.latitude : parsed.lat);
					var lon = (parsed.longitude !== undefined ? parsed.longitude : parsed.lon);
					if (lat !== undefined && lon !== undefined && lat !== "" && lon !== "") {
						root.ipCity = parsed.city || "";
						root.ipLat = lat;
						root.ipLon = lon;
						root.fetchForecast(lat, lon);
					}
				} catch (e) {
					console.warn("IP location parse error:", e);
				}
			}
		}
	}

	Process {
		id: forecastProc
		stdout: StdioCollector {
			waitForEnd: true
			onStreamFinished: {
				var raw = String(text || "").trim();
				if (!raw) return;
				try {
					var parsed = JSON.parse(raw);
					root.report = parsed;
					root.current = WeatherModel.parseOpenMeteoCurrent(parsed);
					root.hourlyForecast = WeatherModel.parseOpenMeteoHourly(parsed);
					root.forecastDays = WeatherModel.parseOpenMeteoDaily(parsed, Qt.formatDate(new Date(), "yyyy-MM-dd"));
					var hl = WeatherModel.parseTodayHighLow(parsed);
					root.reportTodayHigh = hl.high;
					root.reportTodayLow = hl.low;
					if (root.current) {
						root.label = root.current.icon;
						root.tempNum = root.current.tempNum;
						root.reportFeels = root.current.feelsLike;
						root.reportWind = root.current.wind;
						root.reportHumidity = root.current.humidity;
					}
					root.finishSavingLocation();
				} catch (e) {
					console.warn("Weather forecast parse error:", e);
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
		}
	}

	Timer {
		id: refreshTimer
		interval: root.refreshMinutes * 60 * 1000
		running: true
		repeat: true
		triggeredOnStart: false
		onTriggered: root.refresh()
	}

	IpcHandler {
		target: "weather"

		function open(): void { root.open() }
		function close(): void { root.close() }
		function toggle(): void { root.toggle() }
		function refresh(): void { root.refresh() }
		function status(): string { return root.status() }
		function icon(): string { return root.label }
	}
}
