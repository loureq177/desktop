.pragma library

// What the launcher's search does with the text typed: matching names (the
// apps, the actions and the keys) and plain arithmetic.

// How well ql (lowercase) matches text: 0 when the text starts with it, 1 when
// one of its words does, 2 when it is anywhere in it, -1 when it is not.
function fieldScore(text, ql) {
	var h = (text || "").toLowerCase();
	if (h === "" || ql === "")
		return -1;
	if (h.startsWith(ql))
		return 0;
	if (h.split(/[^a-z0-9ąćęłńóśźż]+/).some(w => w.startsWith(ql)))
		return 1;
	return h.indexOf(ql) !== -1 ? 2 : -1;
}

// How well q matches a thing described by fields, [[text, weight], ...] best
// field first: the first field that matches gives its weight plus its
// fieldScore. Lower is better; everything matches nothing typed (0), -1 is no
// match.
function matchScore(fields, q) {
	var ql = (q || "").toLowerCase().trim();
	if (ql === "")
		return 0;
	for (var i = 0; i < fields.length; i++) {
		var s = fieldScore(fields[i][0], ql);
		if (s !== -1)
			return fields[i][1] + s;
	}
	return -1;
}

// The items that score (scoreOf(item) !== -1), best first; equals by `tie`,
// or else in their own order (V4's sort is not stable).
function rank(items, scoreOf, tie) {
	var scored = [];
	for (var i = 0; i < items.length; i++) {
		var s = scoreOf(items[i]);
		if (s !== -1)
			scored.push({ score: s, order: i, item: items[i] });
	}
	scored.sort((a, b) => a.score - b.score || (tie ? tie(a.item, b.item) : 0) || a.order - b.order);
	return scored.map(x => x.item);
}

// A desktop entry: its name, then what kind of app it is, its keywords, its
// id and its comment.
function appScore(entry, q) {
	return matchScore([
		[entry.name, 0],
		[entry.genericName, 3],
		[(entry.keywords || []).join(" "), 6],
		[entry.id, 9],
		[entry.comment, 12]
	], q);
}

// A special workspace or a command, on appScore's scale: its name, then its
// description and its keywords.
function itemScore(item, q) {
	return matchScore([[item.label, 0], [item.subtitle, 3], [item.keywords, 6]], q);
}

// "2+2", "15% * 80", "1,5 x 4": plain arithmetic, at once, or null.
function calculate(raw) {
	var s = (raw || "").trim();
	if (s.startsWith("="))
		s = s.substring(1).trim();
	if (s === "")
		return null;
	if (!/^[0-9+\-*/^().,% xX÷]+$/.test(s))
		return null;
	s = s.replace(/(\d),(\d)/g, "$1.$2");
	if (s.indexOf(",") !== -1)
		return null;
	s = s.replace(/x|X/g, "*").replace(/÷/g, "/");
	if (!/[+\-*/^%]/.test(s))
		return null;
	s = s.replace(/\^/g, "**");
	s = s.replace(/(\d+(?:\.\d+)?)%/g, "($1/100)");

	try {
		var res = new Function("return (" + s + ")")();
		if (typeof res === "number" && isFinite(res))
			return String(Math.round(res * 1e10) / 1e10);
	} catch (e) {
		return null;
	}
	return null;
}
