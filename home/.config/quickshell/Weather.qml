pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "WeatherModel.js" as WeatherModel

Singleton {
	id: root

	// parseOpenMeteoCurrent's fields; null until the first forecast arrives.
	property var current: null
	property var today: ({ high: "", low: "" })
	property var hourlyForecast: []
	property var forecastDays: []

	property string ipCity: ""

	property var configuredLocationState: ({ name: "", latitude: null, longitude: null })
	readonly property string configuredLocation: configuredLocationState.name

	FileView {
		id: locationFile
		path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/weather/weather.json"
		printErrors: false
		onSaveFailed: root.savingLocation = false
		onLoaded: {
			root.configuredLocationState = WeatherModel.parseLocationFile(this.text());
			root.refresh();
		}
		onLoadFailed: {
			root.configuredLocationState = WeatherModel.parseLocationFile("");
			root.refresh();
		}
	}

	property bool editingLocation: false
	property bool savingLocation: false
	property var locationSuggestions: []
	property int suggestionIndex: 0
	property string geocodePendingQuery: ""
	property string geocodeActiveQuery: ""
	// The query the suggestions on screen answer; they lag behind the typing.
	property string suggestionsQuery: ""

	property string lastError: ""
	property string pendingForecastUrl: ""

	readonly property int refreshMinutes: 15

	// A name saved without coordinates could not be geocoded: the forecast is
	// then the IP location's, and must not be labelled with that name.
	readonly property bool configuredHasCoordinates: configuredLocationState.latitude !== null && configuredLocationState.longitude !== null
	readonly property string reportLocation: (configuredHasCoordinates ? configuredLocation : "") || ipCity || configuredLocation || (current ? "Current Location" : "")

	readonly property string tooltipText: {
		if (!current)
			return reportLocation || "Weather";
		// The bar shows the temperature already; the panel has the rest.
		var range = today.high && today.low ? "↑" + today.high + " ↓" + today.low : "";
		return [reportLocation, range].filter(p => p).join(" · ") || "Weather";
	}

	function refresh() {
		if (lastError !== "")
			lastError = "";
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
		if (forecastProc.running) {
			root.pendingForecastUrl = url;
			return;
		}
		forecastProc.command = ["curl", "-fsS", "--max-time", "6", url];
		forecastProc.running = true;
	}

	function startEditingLocation() {
		editingLocation = true;
		savingLocation = false;
		locationSuggestions = [];
		suggestionsQuery = "";
		suggestionIndex = 0;
	}

	function cancelEditingLocation() {
		editingLocation = false;
		savingLocation = false;
		locationSuggestions = [];
		suggestionsQuery = "";
		geocodeDebounce.stop();
	}

	function commitLocation(text) {
		var name = String(text || "").trim();
		if (name === "") {
			clearLocation();
			return;
		}
		savingLocation = true;
		// Suggestions for an older query are not what was typed: look the name up
		// first. Without a match it is kept with no coordinates.
		if (suggestionsQuery !== name) {
			geocodeDebounce.stop();
			geocodePendingQuery = name;
			startGeocode();
			return;
		}
		saveLocation(WeatherModel.locationCommit(name, locationSuggestions, suggestionIndex));
	}

	function clearLocation() {
		ipCity = "";
		saveLocation(WeatherModel.locationCommit("", [], 0));
		cancelEditingLocation();
	}

	function pickSuggestion(suggestion) {
		if (!suggestion)
			return;
		savingLocation = true;
		saveLocation(suggestion);
	}

	function saveLocation(location) {
		configuredLocationState = {
			name: location.name,
			latitude: location.latitude,
			longitude: location.longitude
		};
		locationFile.setText(JSON.stringify(configuredLocationState) + "\n");
		refresh();
	}

	function finishSavingLocation() {
		if (savingLocation)
			cancelEditingLocation();
	}

	function requestGeocode(query) {
		var q = String(query || "").trim();
		if (q.length < 2) {
			geocodeDebounce.stop();
			geocodePendingQuery = "";
			locationSuggestions = [];
			suggestionsQuery = "";
			return;
		}
		geocodePendingQuery = q;
		geocodeDebounce.restart();
	}

	function startGeocode() {
		if (geocodePendingQuery === "" || !editingLocation)
			return;
		// A lookup in flight picks the newer query up when it ends; killing it
		// would report an empty result first and blank the list.
		if (geocodeProc.running)
			return;
		geocodeActiveQuery = geocodePendingQuery;
		geocodeProc.command = [
			"curl", "-fsS", "--max-time", "5",
			"https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(geocodeActiveQuery) + "&count=5&language=en&format=json"
		];
		geocodeProc.running = true;
	}

	Process {
		id: ipProc
		// ipwho.is answers 200 with success=false when it cannot place the address.
		command: ["curl", "-fsS", "--max-time", "4", "https://ipwho.is/?fields=success,city,latitude,longitude"]
		onExited: code => {
			if (code === 0)
				return;
			root.finishSavingLocation();
			if (!root.current)
				root.lastError = "Offline — couldn't detect location";
		}
		stdout: StdioCollector {
			waitForEnd: true
			onStreamFinished: {
				var raw = String(text || "").trim();
				if (!raw) return;
				try {
					var parsed = JSON.parse(raw);
					if (parsed.success && typeof parsed.latitude === "number" && typeof parsed.longitude === "number") {
						root.ipCity = parsed.city || "";
						root.fetchForecast(parsed.latitude, parsed.longitude);
					} else if (!root.current) {
						root.lastError = "Couldn't detect location";
					}
				} catch (e) {
					console.warn("IP location parse error:", e);
				}
			}
		}
	}

	Process {
		id: forecastProc
		onExited: code => {
			if (root.pendingForecastUrl !== "") {
				var next = root.pendingForecastUrl;
				root.pendingForecastUrl = "";
				forecastProc.command = ["curl", "-fsS", "--max-time", "6", next];
				forecastProc.running = true;
				return;
			}
			if (code !== 0) {
				// The location is saved all the same; only its forecast is missing.
				root.finishSavingLocation();
				if (!root.current)
					root.lastError = "Offline — couldn't fetch forecast";
			} else if (root.lastError.indexOf("Offline") === 0) {
				root.lastError = "";
			}
		}
		stdout: StdioCollector {
			waitForEnd: true
			onStreamFinished: {
				var raw = String(text || "").trim();
				if (!raw) return;
				try {
					var parsed = JSON.parse(raw);
					root.current = WeatherModel.parseOpenMeteoCurrent(parsed);
					root.hourlyForecast = WeatherModel.parseOpenMeteoHourly(parsed);
					root.forecastDays = WeatherModel.parseOpenMeteoDaily(parsed, Qt.formatDate(new Date(), "yyyy-MM-dd"));
					root.today = WeatherModel.parseTodayHighLow(parsed);
					root.finishSavingLocation();
				} catch (e) {
					console.warn("Weather forecast parse error:", e);
					if (!root.current)
						root.lastError = "Couldn't parse forecast";
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
				root.suggestionsQuery = root.geocodeActiveQuery;
				root.suggestionIndex = 0;
				if (root.editingLocation && root.geocodePendingQuery !== "" && root.geocodePendingQuery !== root.geocodeActiveQuery)
					geocodeDebounce.restart();
				else if (root.savingLocation)
					root.commitLocation(root.suggestionsQuery);
			}
		}
	}

	Timer {
		id: geocodeDebounce
		interval: 250
		repeat: false
		onTriggered: root.startGeocode()
	}

	Timer {
		id: refreshTimer
		interval: root.refreshMinutes * 60 * 1000
		running: true
		repeat: true
		triggeredOnStart: false
		onTriggered: root.refresh()
	}

}
