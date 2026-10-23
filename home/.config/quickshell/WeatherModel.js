// ~/.config/weather.json: the place the forecast is for, coordinates and all.
function parseLocationFile(raw) {
	var unset = { name: "", latitude: null, longitude: null };
	try {
		var data = JSON.parse(String(raw || ""));
		if (!data || typeof data !== "object") return unset;

		var latitude = parseFloat(data.latitude);
		var longitude = parseFloat(data.longitude);
		var hasCoordinates = !isNaN(latitude) && !isNaN(longitude);
		return {
			name: typeof data.name === "string" ? data.name.trim() : "",
			latitude: hasCoordinates ? latitude : null,
			longitude: hasCoordinates ? longitude : null
		};
	} catch (e) {
		return unset;
	}
}

function dayName(dateString) {
	if (!dateString) return "";
	var d = new Date(dateString + "T12:00:00");
	if (isNaN(d.getTime())) return "";
	return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][d.getDay()];
}

// Name of the line icon (widgets/LineIcons.js) for a WMO weather code.
function iconForWmoCode(code, isDay) {
	var c = parseInt(String(code || "0"), 10);
	var day = (isDay === true || isDay === 1 || isDay === "1");

	switch (c) {
		case 0:
			return day ? "sun" : "moon";
		case 1:
		case 2:
			return day ? "cloud-sun" : "cloud-moon";
		case 3:
			return "cloud";
		case 45:
		case 48:
			return "cloud-fog";
		case 51:
		case 53:
		case 55:
			return "cloud-drizzle";
		case 56:
		case 57:
		case 66:
		case 67:
			return "cloud-hail";
		case 61:
		case 63:
		case 65:
		case 80:
		case 81:
		case 82:
			return "cloud-rain";
		case 71:
		case 73:
		case 75:
		case 77:
		case 85:
		case 86:
			return "cloud-snow";
		case 95:
		case 96:
		case 99:
			return "cloud-lightning";
		default:
			return day ? "sun" : "moon";
	}
}

function parseOpenMeteoCurrent(report) {
	var c = report && report.current ? report.current : null;
	if (!c || c.temperature_2m === undefined || c.temperature_2m === null) return null;

	var tempVal = Math.round(c.temperature_2m);
	var feelsVal = Math.round(c.apparent_temperature !== undefined && c.apparent_temperature !== null ? c.apparent_temperature : c.temperature_2m);

	return {
		tempNum: String(tempVal),
		feelsLike: String(feelsVal) + "°C",
		wind: Math.round(c.wind_speed_10m || 0) + " km/h",
		humidity: String(Math.round(c.relative_humidity_2m || 0)) + "%",
		icon: iconForWmoCode(c.weather_code || 0, Number(c.is_day) === 1)
	};
}

function parseOpenMeteoHourly(report) {
	var hourly = report && report.hourly ? report.hourly : null;
	if (!hourly || !hourly.time || !hourly.time.length) return [];

	var result = [];
	var limit = Math.min(hourly.time.length, 27);
	for (var i = 0; i < limit; i++) {
		var rawTime = hourly.time[i];
		var hourStr = "";
		if (i === 0) {
			hourStr = "Now";
		} else {
			var parts = String(rawTime).split("T");
			hourStr = parts[1] ? parts[1].slice(0, 5) : rawTime;
		}
		var code = hourly.weather_code ? hourly.weather_code[i] : 0;
		var isDay = hourly.is_day ? Number(hourly.is_day[i]) === 1 : true;

		result.push({
			time: hourStr,
			temp: Math.round(hourly.temperature_2m ? hourly.temperature_2m[i] : 0),
			icon: iconForWmoCode(code, isDay),
			pop: hourly.precipitation_probability ? Math.round(hourly.precipitation_probability[i] || 0) : 0
		});
	}
	return result;
}

function parseTodayHighLow(report) {
	var daily = report && report.daily ? report.daily : null;
	if (!daily || !daily.temperature_2m_max || !daily.temperature_2m_min) {
		return { high: "", low: "" };
	}
	var maxC = daily.temperature_2m_max[0];
	var minC = daily.temperature_2m_min[0];
	if (maxC === undefined || minC === undefined || maxC === null || minC === null) {
		return { high: "", low: "" };
	}
	var maxVal = Math.round(maxC);
	var minVal = Math.round(minC);
	return {
		high: String(maxVal) + "°",
		low: String(minVal) + "°"
	};
}

function parseOpenMeteoDaily(report, todayString) {
	var daily = report && report.daily ? report.daily : null;
	if (!daily || !daily.time) return [];

	var result = [];
	for (var i = 0; i < daily.time.length && result.length < 3; i++) {
		var date = daily.time[i];
		if (todayString && date <= todayString) continue;

		var maxC = daily.temperature_2m_max ? daily.temperature_2m_max[i] : 0;
		var minC = daily.temperature_2m_min ? daily.temperature_2m_min[i] : 0;

		result.push({
			date: date,
			dayName: dayName(date),
			maxTemp: String(Math.round(maxC)) + "°",
			minTemp: String(Math.round(minC)) + "°",
			icon: iconForWmoCode(daily.weather_code ? daily.weather_code[i] : 0, true)
		});
	}
	return result;
}

// Where each hour of the temperature chart sits: x in the middle of its
// column, y from `top` (the warmest hour) down to `top + height` (the coldest).
// A spread under 3° is drawn as 3°, so a steady day stays a flat line.
function chartPoints(hours, columnWidth, top, height) {
	if (!hours || !hours.length) return [];
	var temps = hours.map(function (h) { return h.temp; });
	var maxT = Math.max.apply(null, temps);
	var range = Math.max(3, maxT - Math.min.apply(null, temps));
	return hours.map(function (h, i) {
		return { x: i * columnWidth + columnWidth / 2, y: top + (maxT - h.temp) / range * height };
	});
}

if (typeof module !== "undefined") {
	module.exports = {
		parseLocationFile: parseLocationFile,
		dayName: dayName,
		iconForWmoCode: iconForWmoCode,
		parseOpenMeteoCurrent: parseOpenMeteoCurrent,
		parseOpenMeteoHourly: parseOpenMeteoHourly,
		parseTodayHighLow: parseTodayHighLow,
		parseOpenMeteoDaily: parseOpenMeteoDaily,
		chartPoints: chartPoints
	};
}
