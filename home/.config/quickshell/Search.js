.pragma library

// What the launcher's search does with the text typed: matching names (the
// apps, the actions, the keys and the commands), plain arithmetic and the
// files ("/" and a name, found by fd).

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

// A special workspace or an action, on appScore's scale: its name, then its
// description and its keywords.
function itemScore(item, q) {
	return matchScore([[item.label, 0], [item.desc, 3], [item.keywords, 6]], q);
}

// The commands (compgen -c) for what was typed after ">": all of them for
// nothing typed, else what was typed itself, then the commands that start
// with it, then those that have it further in; `limit` at most.
function matchCommands(commands, typed, limit) {
	var t = (typed || "").trim();
	if (t === "")
		return commands.slice();
	var tl = t.toLowerCase();
	var starts = [];
	var within = [];
	for (var i = 0; i < commands.length; i++) {
		var at = commands[i].toLowerCase().indexOf(tl);
		if (at === 0 && commands[i].toLowerCase() !== tl)
			starts.push(commands[i]);
		else if (at > 0)
			within.push(commands[i]);
	}
	return [t].concat(starts, within).slice(0, limit);
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

// The words of a file search ("/" and the words of the name), or null when q
// is not one.
function fileTerms(raw) {
	var s = (raw || "").trim();
	if (!s.startsWith("/"))
		return null;
	return s.substring(1).trim().split(/\s+/).filter(w => w !== "");
}

// fd's arguments for the words: files and folders under home whose name has
// all of them, hidden and ignored ones left out.
function fdCommand(terms, home, limit) {
	var cmd = ["fd", "--type", "f", "--type", "d", "--ignore-case", "--fixed-strings",
		"--max-results", String(limit), "--exclude", "node_modules", "--exclude", "__pycache__"];
	for (var i = 1; i < terms.length; i++)
		cmd.push("--and", terms[i]);
	return cmd.concat([terms[0], home]);
}

var extIcons = {
	"image": ["png", "jpg", "jpeg", "gif", "webp", "svg", "heic", "avif", "bmp", "tiff"],
	"video": ["mp4", "mkv", "webm", "mov", "avi"],
	"music": ["mp3", "flac", "ogg", "opus", "wav", "m4a"],
	"package": ["zip", "tar", "gz", "xz", "zst", "7z", "rar", "appimage"],
	"file-text": ["pdf", "txt", "md", "doc", "docx", "odt", "rtf", "tex", "epub", "csv", "xlsx", "ods", "pptx", "odp"],
	"code": ["py", "js", "ts", "qml", "lua", "sh", "c", "h", "cpp", "rs", "go", "java", "json", "toml", "yaml", "yml", "html", "css", "ipynb"]
};

function fileIcon(name, isDir) {
	if (isDir)
		return "folder";
	var dot = name.lastIndexOf(".");
	var ext = dot > 0 ? name.substring(dot + 1).toLowerCase() : "";
	for (var icon in extIcons) {
		if (extIcons[icon].indexOf(ext) !== -1)
			return icon;
	}
	return "file";
}

// The files fd printed (folders end in "/"), best first: the name starting
// with the first word, then a word of it, then anywhere; nearer home before
// deeper; shorter names first. { path, name, dir ("~/..."), isDir, icon }.
function rankFiles(lines, terms, home, limit) {
	var first = (terms[0] || "").toLowerCase();
	var out = [];
	for (var i = 0; i < lines.length; i++) {
		var line = lines[i].trim();
		if (line === "")
			continue;
		var isDir = line.endsWith("/");
		var path = isDir ? line.substring(0, line.length - 1) : line;
		var cut = path.lastIndexOf("/");
		var name = path.substring(cut + 1);
		var parent = path.substring(0, cut);
		var lower = name.toLowerCase();
		var at = lower.indexOf(first);
		var score = at === 0 ? 0 : at > 0 && !/[a-z0-9ąćęłńóśźż]/.test(lower[at - 1]) ? 1 : 2;
		out.push({
			path: path,
			name: name,
			dir: parent === home ? "~" : parent.startsWith(home + "/") ? "~" + parent.substring(home.length) : parent,
			isDir: isDir,
			icon: fileIcon(name, isDir),
			score: score,
			depth: path.split("/").length
		});
	}
	out.sort((a, b) => a.score - b.score || a.depth - b.depth || a.name.length - b.name.length || a.name.localeCompare(b.name));
	return out.slice(0, limit);
}
