// WeatherModel.js: the parsing behind the quickshell weather widget.
// Run with: node --test tests/js

const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");

const m = require(path.join(__dirname, "../../archlinux/.config/quickshell/WeatherModel.js"));

const UNSET = { name: "", latitude: null, longitude: null };

test("parseLocationFile: reads a saved location", () => {
  assert.deepEqual(m.parseLocationFile('{"name":" Kraków ","latitude":50.06,"longitude":19.94}'), {
    name: "Kraków",
    latitude: 50.06,
    longitude: 19.94,
  });
});

test("parseLocationFile: a name without coordinates is still a location", () => {
  assert.deepEqual(m.parseLocationFile('{"name":"Gdańsk"}'), { name: "Gdańsk", latitude: null, longitude: null });
  // half a coordinate pair is no coordinate
  assert.deepEqual(m.parseLocationFile('{"name":"X","latitude":1.5}'), { name: "X", latitude: null, longitude: null });
});

test("parseLocationFile: 0,0 is a real coordinate", () => {
  assert.deepEqual(m.parseLocationFile('{"name":"Null Island","latitude":0,"longitude":0}'), {
    name: "Null Island",
    latitude: 0,
    longitude: 0,
  });
});

test("parseLocationFile: anything unreadable means no location", () => {
  for (const raw of ["", null, undefined, "not json", "null", "42", '"text"', "{"]) {
    assert.deepEqual(m.parseLocationFile(raw), UNSET, `input: ${raw}`);
  }
  assert.deepEqual(m.parseLocationFile('{"name":7,"latitude":"x","longitude":null}'), UNSET);
});

test("dayName: names the weekday of an ISO date", () => {
  assert.equal(m.dayName("2026-10-12"), "Monday");
  assert.equal(m.dayName("2026-10-18"), "Sunday");
  for (const bad of ["", null, undefined, "not-a-date"]) assert.equal(m.dayName(bad), "");
});

test("iconForWmoCode: every documented WMO code has an icon, day and night", () => {
  const codes = [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99];
  for (const code of codes) {
    for (const day of [true, false]) {
      const icon = m.iconForWmoCode(code, day);
      assert.equal(typeof icon, "string");
      assert.ok(icon.length > 0, `no icon for code ${code} (day=${day})`);
    }
  }
  assert.ok(m.iconForWmoCode(1234, true).length > 0, "unknown codes still get an icon");
});

test("iconForWmoCode: clear sky differs between day and night, however day is spelled", () => {
  const day = m.iconForWmoCode(0, true);
  const night = m.iconForWmoCode(0, false);
  assert.notEqual(day, night);
  assert.equal(m.iconForWmoCode(0, 1), day);
  assert.equal(m.iconForWmoCode(0, "1"), day);
  assert.equal(m.iconForWmoCode("0", 0), night);
  assert.equal(m.iconForWmoCode(undefined, undefined), night);
});

test("parseOpenMeteoCurrent: rounds and labels the current conditions", () => {
  const current = m.parseOpenMeteoCurrent({
    current: {
      temperature_2m: 11.6,
      apparent_temperature: 9.4,
      wind_speed_10m: 14.5,
      relative_humidity_2m: 71.2,
      weather_code: 61,
      is_day: 1,
    },
  });
  assert.deepEqual(current, {
    tempNum: "12",
    feelsLike: "9°C",
    wind: "15 km/h",
    humidity: "71%",
    icon: m.iconForWmoCode(61, true),
  });
});

test("parseOpenMeteoCurrent: zero degrees is a temperature, not missing data", () => {
  const current = m.parseOpenMeteoCurrent({ current: { temperature_2m: 0, apparent_temperature: 0, is_day: 0 } });
  assert.equal(current.tempNum, "0");
  assert.equal(current.feelsLike, "0°C");
  assert.equal(current.icon, m.iconForWmoCode(0, false));
  assert.equal(m.parseOpenMeteoCurrent({ current: { temperature_2m: -0.4 } }).tempNum, "0");
});

test("parseOpenMeteoCurrent: feels-like falls back to the temperature", () => {
  assert.equal(m.parseOpenMeteoCurrent({ current: { temperature_2m: 7.2 } }).feelsLike, "7°C");
  assert.equal(m.parseOpenMeteoCurrent({ current: { temperature_2m: 7.2, apparent_temperature: null } }).feelsLike, "7°C");
});

test("parseOpenMeteoCurrent: no usable report means null", () => {
  for (const report of [null, undefined, {}, { current: null }, { current: {} }, { current: { temperature_2m: null } }]) {
    assert.equal(m.parseOpenMeteoCurrent(report), null);
  }
});

test("parseOpenMeteoHourly: labels the first hour Now and the rest by clock time", () => {
  const hourly = m.parseOpenMeteoHourly({
    hourly: {
      time: ["2026-10-12T14:00", "2026-10-12T15:00", "2026-10-12T16:00"],
      temperature_2m: [11.6, 10.4, -0.6],
      weather_code: [0, 61, 71],
      is_day: [1, 1, 0],
      precipitation_probability: [0, 64.6, null],
    },
  });
  assert.deepEqual(
    hourly.map((h) => [h.time, h.temp, h.icon, h.pop]),
    [
      ["Now", 12, m.iconForWmoCode(0, true), 0],
      ["15:00", 10, m.iconForWmoCode(61, true), 65],
      ["16:00", -1, m.iconForWmoCode(71, false), 0],
    ],
  );
});

test("parseOpenMeteoHourly: shows at most 27 hours and tolerates sparse reports", () => {
  const time = Array.from({ length: 48 }, (_, i) => `2026-10-12T${String(i % 24).padStart(2, "0")}:00`);
  const hourly = m.parseOpenMeteoHourly({ hourly: { time } });
  assert.equal(hourly.length, 27);
  assert.deepEqual([hourly[1].time, hourly[1].icon, hourly[1].pop], ["01:00", m.iconForWmoCode(0, true), 0]);
  for (const report of [null, {}, { hourly: null }, { hourly: {} }, { hourly: { time: [] } }]) {
    assert.deepEqual(m.parseOpenMeteoHourly(report), []);
  }
});

test("parseTodayHighLow: rounds today's extremes", () => {
  assert.deepEqual(m.parseTodayHighLow({ daily: { temperature_2m_max: [14.5, 20], temperature_2m_min: [-0.2, 5] } }), {
    high: "15°",
    low: "0°",
  });
  assert.deepEqual(m.parseTodayHighLow({ daily: { temperature_2m_max: [0], temperature_2m_min: [0] } }), { high: "0°", low: "0°" });
});

test("parseTodayHighLow: blanks when the report has no extremes", () => {
  const blank = { high: "", low: "" };
  for (const report of [
    null,
    {},
    { daily: {} },
    { daily: { temperature_2m_max: [], temperature_2m_min: [] } },
    { daily: { temperature_2m_max: [null], temperature_2m_min: [3] } },
  ]) {
    assert.deepEqual(m.parseTodayHighLow(report), blank);
  }
});

test("parseOpenMeteoDaily: gives the next three days after today", () => {
  const report = {
    daily: {
      time: ["2026-10-11", "2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15", "2026-10-16"],
      temperature_2m_max: [1, 2, 13.5, 14.4, 15, 16],
      temperature_2m_min: [0, 1, 3.5, 4.4, 5, 6],
      weather_code: [0, 0, 61, 3, 71, 95],
    },
  };
  const daily = m.parseOpenMeteoDaily(report, "2026-10-12");
  assert.deepEqual(
    daily.map((d) => [d.date, d.dayName, d.maxTemp, d.minTemp, d.icon]),
    [
      ["2026-10-13", "Tuesday", "14°", "4°", m.iconForWmoCode(61, true)],
      ["2026-10-14", "Wednesday", "14°", "4°", m.iconForWmoCode(3, true)],
      ["2026-10-15", "Thursday", "15°", "5°", m.iconForWmoCode(71, true)],
    ],
  );
});

test("parseOpenMeteoDaily: without a date for today starts at the first day; no data gives nothing", () => {
  const report = { daily: { time: ["2026-10-12", "2026-10-13"] } };
  assert.deepEqual(m.parseOpenMeteoDaily(report).map((d) => d.date), ["2026-10-12", "2026-10-13"]);
  for (const empty of [null, {}, { daily: {} }, { daily: { time: [] } }]) {
    assert.deepEqual(m.parseOpenMeteoDaily(empty, "2026-10-12"), []);
  }
});

test("chartPoints: the warmest hour on top, the coldest at the bottom", () => {
  const pts = m.chartPoints([{ temp: 10 }, { temp: 20 }, { temp: 15 }], 54, 78, 50);
  assert.deepEqual(pts.map((p) => p.x), [27, 81, 135]);
  assert.deepEqual(pts.map((p) => p.y), [128, 78, 103]);
});

test("chartPoints: a spread under 3 degrees is drawn as 3", () => {
  const pts = m.chartPoints([{ temp: 10 }, { temp: 11 }], 54, 0, 30);
  assert.deepEqual(pts.map((p) => p.y), [10, 0]);
});

test("chartPoints: no hours, no points", () => {
  assert.deepEqual(m.chartPoints([], 54, 78, 50), []);
  assert.deepEqual(m.chartPoints(null, 54, 78, 50), []);
});
