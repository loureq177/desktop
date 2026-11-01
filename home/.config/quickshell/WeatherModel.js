// ~/.config/weather.json: the place the forecast is for, coordinates and all.
function parseLocationFile(raw) {
	var data = {};
	try {
		data = JSON.parse(String(raw || "")) || {};
	} catch (e) {}
	var latitude = parseFloat(data.latitude);
	var longitude = parseFloat(data.longitude);
	var hasCoordinates = !isNaN(latitude) && !isNaN(longitude);
	return {
		name: typeof data.name === "string" ? data.name.trim() : "",
		latitude: hasCoordinates ? latitude : null,
		longitude: hasCoordinates ? longitude : null
	};
}

function dayName(date) {
	return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][new Date(date + "T12:00:00").getDay()];
}

// The line icon (widgets/LineIcons.js) of a WMO weather code; a clear sky or few
// clouds, and what is not listed, have a day and a night.
var wmoIcons = {
	3: "cloud",
	45: "cloud-fog", 48: "cloud-fog",
	51: "cloud-drizzle", 53: "cloud-drizzle", 55: "cloud-drizzle",
	56: "cloud-hail", 57: "cloud-hail", 66: "cloud-hail", 67: "cloud-hail",
	61: "cloud-rain", 63: "cloud-rain", 65: "cloud-rain", 80: "cloud-rain", 81: "cloud-rain", 82: "cloud-rain",
	71: "cloud-snow", 73: "cloud-snow", 75: "cloud-snow", 77: "cloud-snow", 85: "cloud-snow", 86: "cloud-snow",
	95: "cloud-lightning", 96: "cloud-lightning", 99: "cloud-lightning"
};

function iconForWmoCode(code, isDay) {
	if (code === 1 || code === 2)
		return isDay ? "cloud-sun" : "cloud-moon";
	return wmoIcons[code] ?? (isDay ? "sun" : "moon");
}

// Open-Meteo's answer as the shell shows it; what is missing from it throws, and
// Weather.qml says the forecast could not be read.
function parseOpenMeteoCurrent(report) {
	var c = report.current;
	return {
		tempNum: String(Math.round(c.temperature_2m)),
		feelsLike: Math.round(c.apparent_temperature) + "°C",
		wind: Math.round(c.wind_speed_10m) + " km/h",
		humidity: Math.round(c.relative_humidity_2m) + "%",
		icon: iconForWmoCode(c.weather_code, c.is_day === 1)
	};
}

function parseOpenMeteoHourly(report) {
	var h = report.hourly;
	return h.time.map((time, i) => ({
		time: i === 0 ? "Now" : time.split("T")[1].slice(0, 5),
		temp: Math.round(h.temperature_2m[i]),
		icon: iconForWmoCode(h.weather_code[i], h.is_day[i] === 1),
		pop: Math.round(h.precipitation_probability[i] || 0)
	}));
}

function parseTodayHighLow(report) {
	return {
		high: Math.round(report.daily.temperature_2m_max[0]) + "°",
		low: Math.round(report.daily.temperature_2m_min[0]) + "°"
	};
}

// Each day's sunrise and sunset in milliseconds, by yyyy-MM-dd.
function parseSunTimes(report) {
	var d = report.daily;
	var days = {};
	d.time.forEach((date, i) => {
		days[date] = { rise: new Date(d.sunrise[i]).getTime(), set: new Date(d.sunset[i]).getTime() };
	});
	return days;
}

// How far the sun is through `day` at `now`, 0..1; -1 at night or for a day not known.
function sunProgress(day, now) {
	if (!day || now < day.rise || now > day.set)
		return -1;
	return (now - day.rise) / (day.set - day.rise);
}

// The days after `today` (yyyy-MM-dd), three at most.
function parseOpenMeteoDaily(report, today) {
	var d = report.daily;
	return d.time.map((date, i) => ({
		date: date,
		dayName: dayName(date),
		maxTemp: Math.round(d.temperature_2m_max[i]) + "°",
		minTemp: Math.round(d.temperature_2m_min[i]) + "°",
		icon: iconForWmoCode(d.weather_code[i], true)
	})).filter(day => day.date > today).slice(0, 3);
}

// Each hour's point on the chart: x mid-column, y from the warmest (top) to the
// coldest; under 3° of spread draws as 3°.
function chartPoints(hours, columnWidth, top, height) {
	if (!hours || !hours.length) return [];
	var temps = hours.map(h => h.temp);
	var maxT = Math.max(...temps);
	var range = Math.max(3, maxT - Math.min(...temps));
	return hours.map((h, i) => ({ x: i * columnWidth + columnWidth / 2, y: top + (maxT - h.temp) / range * height }));
}
