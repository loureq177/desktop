// Open-Meteo Weather Model & Utilities

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

function parseGeocodingResults(raw) {
  try {
    var data = JSON.parse(String(raw || "{}"));
    var results = data.results;
    if (!results || !results.length) return [];

    var out = [];
    for (var i = 0; i < results.length; i++) {
      var r = results[i];
      if (!r || !r.name || r.latitude === undefined || r.longitude === undefined) continue;
      var region = [r.admin1, r.country].filter(function(part) { return !!part; }).join(", ");
      out.push({
        name: String(r.name),
        description: region,
        latitude: r.latitude,
        longitude: r.longitude
      });
    }
    return out;
  } catch (e) {
    return [];
  }
}

function locationCommit(text, suggestions, selectedIndex) {
  var name = String(text || "").trim();
  if (name === "") return { name: "", latitude: null, longitude: null };

  var choices = suggestions || [];
  var index = Math.max(0, Math.min(parseInt(selectedIndex, 10) || 0, choices.length - 1));
  var suggestion = choices[index];
  if (suggestion) return suggestion;

  return { name: name, latitude: null, longitude: null };
}

function formatTemp(value) {
  if (value === undefined || value === null || value === "") return "";
  return value + "°C";
}

function dayName(dateString, formatter) {
  if (!dateString) return "";
  var d = new Date(dateString + "T12:00:00");
  if (isNaN(d.getTime())) return "";
  if (formatter) return formatter(d);
  return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][d.getDay()];
}

// WMO Weather Interpretation Codes (WW) → Nerd Font Weather Icons
function iconForWmoCode(code, isDay) {
  var c = parseInt(String(code || "0"), 10);
  var day = (isDay === true || isDay === 1 || isDay === "1");

  switch (c) {
    case 0: // Clear sky
      return day ? "" : "";
    case 1: // Mainly clear
    case 2: // Partly cloudy
      return day ? "" : "";
    case 3: // Overcast
      return "";
    case 45: // Fog
    case 48: // Depositing rime fog
      return day ? "" : "";
    case 51: // Drizzle: Light
    case 53: // Drizzle: Moderate
    case 55: // Drizzle: Dense
    case 61: // Rain: Slight
    case 63: // Rain: Moderate
    case 65: // Rain: Heavy
      return "";
    case 56: // Freezing Drizzle: Light
    case 57: // Freezing Drizzle: Dense
    case 66: // Freezing Rain: Light
    case 67: // Freezing Rain: Heavy
      return "";
    case 71: // Snow fall: Slight
    case 73: // Snow fall: Moderate
    case 75: // Snow fall: Heavy
    case 77: // Snow grains
      return "";
    case 80: // Rain showers: Slight
    case 81: // Rain showers: Moderate
    case 82: // Rain showers: Violent
      return day ? "" : "";
    case 85: // Snow showers: Slight
    case 86: // Snow showers: Heavy
      return day ? "" : "";
    case 95: // Thunderstorm: Slight or moderate
    case 96: // Thunderstorm with slight hail
    case 99: // Thunderstorm with heavy hail
      return "";
    default:
      return day ? "" : "";
  }
}

function parseOpenMeteoCurrent(report) {
  var c = report && report.current ? report.current : null;
  if (!c || c.temperature_2m === undefined || c.temperature_2m === null) return null;

  var tempVal = Math.round(c.temperature_2m);
  var feelsVal = Math.round(c.apparent_temperature !== undefined && c.apparent_temperature !== null ? c.apparent_temperature : c.temperature_2m);
  var windVal = Math.round(c.wind_speed_10m || 0) + " km/h";
  var isDay = Number(c.is_day) === 1;
  var code = c.weather_code || 0;

  return {
    tempNum: String(tempVal),
    tempVal: tempVal,
    feelsLike: String(feelsVal) + "°C",
    wind: windVal,
    humidity: String(Math.round(c.relative_humidity_2m || 0)) + "%",
    weatherCode: code,
    isDay: isDay,
    icon: iconForWmoCode(code, isDay)
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
    var tempC = hourly.temperature_2m ? hourly.temperature_2m[i] : 0;
    var tempVal = Math.round(tempC);
    var code = hourly.weather_code ? hourly.weather_code[i] : 0;
    var isDay = hourly.is_day ? Number(hourly.is_day[i]) === 1 : true;
    var pop = hourly.precipitation_probability ? Math.round(hourly.precipitation_probability[i] || 0) : 0;

    result.push({
      time: hourStr,
      temp: tempVal,
      tempStr: String(tempVal) + "°",
      code: code,
      isDay: isDay,
      icon: iconForWmoCode(code, isDay),
      pop: pop
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
    var code = daily.weather_code ? daily.weather_code[i] : 0;
    var maxVal = Math.round(maxC);
    var minVal = Math.round(minC);

    result.push({
      date: date,
      dayName: dayName(date),
      maxTemp: String(maxVal) + "°",
      minTemp: String(minVal) + "°",
      weatherCode: code,
      icon: iconForWmoCode(code, true)
    });
  }
  return result;
}

if (typeof module !== "undefined") {
  module.exports = {
    parseLocationFile: parseLocationFile,
    parseGeocodingResults: parseGeocodingResults,
    locationCommit: locationCommit,
    formatTemp: formatTemp,
    dayName: dayName,
    iconForWmoCode: iconForWmoCode,
    parseOpenMeteoCurrent: parseOpenMeteoCurrent,
    parseOpenMeteoHourly: parseOpenMeteoHourly,
    parseTodayHighLow: parseTodayHighLow,
    parseOpenMeteoDaily: parseOpenMeteoDaily
  };
}
