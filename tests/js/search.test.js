// Search.js: the launcher's calculator and file search, apart from the QML.
// The file is a QML library (".pragma library"), so it is loaded into a
// sandbox.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs
  .readFileSync(path.join(__dirname, "../../archlinux/.config/quickshell/Search.js"), "utf8")
  .replace(/^\.pragma .*$/m, "");
const S = vm.createContext({});
vm.runInContext(source, S);
const plain = (v) => JSON.parse(JSON.stringify(v));

test("calculate does plain arithmetic, with x, ÷, ^, % and a decimal comma", () => {
  assert.equal(S.calculate("2+2"), "4");
  assert.equal(S.calculate("= 2 x 3"), "6");
  assert.equal(S.calculate("9÷3"), "3");
  assert.equal(S.calculate("2^10"), "1024");
  assert.equal(S.calculate("15% * 80"), "12");
  assert.equal(S.calculate("1,5*2"), "3");
  assert.equal(S.calculate("0.1+0.2"), "0.3");
});

test("calculate leaves what is not arithmetic", () => {
  for (const q of ["", "=", "42", "firefox", "2+", "1/0", "10 km to mi", "1,2,3+1"])
    assert.equal(S.calculate(q), null, q);
});

test("qalc gets expressions, not the apps' names", () => {
  for (const q of ["10 km to mi", "100 eur to pln", "sqrt(2)", "10!", "= pi", "=now", "(2+3) m"])
    assert.equal(S.wantsQalc(q), true, q);
  for (const q of ["firefox", "spotify", "7zip", "2048", "1,5", "=", "", "steam 2"])
    assert.equal(S.wantsQalc(q), false, q);
});

test("qalcAnswer keeps a result and drops errors and the expression given back", () => {
  assert.equal(S.qalcAnswer("10 km to mi", "6.213711922 mi\n"), "6.213711922 mi");
  assert.equal(S.qalcAnswer("= 100 eur to pln", "zł 437.30"), "zł 437.30");
  assert.equal(S.qalcAnswer("x+2", "x + 2"), null);
  assert.equal(S.qalcAnswer("10 kg", "10 kg"), null);
  assert.equal(S.qalcAnswer("20% of 80", "rem(20, 1 B)"), null);
  assert.equal(S.qalcAnswer("2+", "error: missing operand\n"), null);
  assert.equal(S.qalcAnswer("1 = 2", "warning: something\nfalse"), "false");
  assert.equal(S.qalcAnswer("sqrt(2)", ""), null);
});

test("fileTerms reads a search that starts with /", () => {
  assert.deepEqual(plain(S.fileTerms("/ faktura  maj ")), ["faktura", "maj"]);
  assert.deepEqual(plain(S.fileTerms("/")), []);
  assert.equal(S.fileTerms("firefox"), null);
});

test("fdCommand asks for every word in the name", () => {
  assert.deepEqual(plain(S.fdCommand(["faktura", "maj"], "/home/u", 300)).slice(-4), ["--and", "maj", "faktura", "/home/u"]);
  const cmd = plain(S.fdCommand(["a"], "/home/u", 300));
  assert.equal(cmd[0], "fd");
  assert.deepEqual(cmd.slice(-2), ["a", "/home/u"]);
  assert.ok(!cmd.includes("--and"));
});

test("rankFiles puts names starting with the word first, then nearer home", () => {
  const home = "/home/u";
  const lines = [
    "/home/u/a/b/old-report.pdf",
    "/home/u/a/report-draft.txt",
    "/home/u/Reports/",
    "/home/u/a/b/c/report.pdf",
    "/home/u/myreport.md",
    "",
  ];
  const ranked = plain(S.rankFiles(lines, ["report"], home, 10));
  assert.deepEqual(ranked.map((f) => f.name), ["Reports", "report-draft.txt", "report.pdf", "old-report.pdf", "myreport.md"]);
  assert.deepEqual(ranked[0], { path: "/home/u/Reports", name: "Reports", dir: "~", isDir: true, icon: "folder", score: 0, depth: 4 });
  assert.equal(ranked[1].dir, "~/a");
  assert.equal(ranked[1].icon, "file-text");
  assert.equal(S.rankFiles(lines, ["report"], home, 2).length, 2);
});

test("fileIcon goes by the extension", () => {
  assert.equal(S.fileIcon("photo.JPG", false), "image");
  assert.equal(S.fileIcon("song.flac", false), "music");
  assert.equal(S.fileIcon("main.py", false), "code");
  assert.equal(S.fileIcon("Makefile", false), "file");
  assert.equal(S.fileIcon(".bashrc", false), "file");
  assert.equal(S.fileIcon("src", true), "folder");
});

test("fieldScore: the start, then the start of a word, then anywhere", () => {
  assert.equal(S.fieldScore("Firefox Web Browser", "fire"), 0);
  assert.equal(S.fieldScore("Firefox Web Browser", "web"), 1);
  assert.equal(S.fieldScore("Firefox Web Browser", "fox"), 2);
  assert.equal(S.fieldScore("Firefox Web Browser", "chrome"), -1);
  assert.equal(S.fieldScore("Zażółć gęślą", "gęś"), 1);
  assert.equal(S.fieldScore("", "a"), -1);
  assert.equal(S.fieldScore(undefined, "a"), -1);
});

test("matchScore: the first field that matches, by its weight", () => {
  const fields = [["Files", 0], ["File manager", 3], ["yazi pliki", 6]];
  assert.equal(S.matchScore(fields, "fil"), 0);
  assert.equal(S.matchScore(fields, "man"), 4);
  assert.equal(S.matchScore(fields, "pliki"), 7);
  assert.equal(S.matchScore(fields, "nothing"), -1);
  assert.equal(S.matchScore(fields, "  "), 0);
});

test("appScore: the name counts before the comment", () => {
  const firefox = { name: "Firefox", genericName: "Web Browser", keywords: ["internet"], id: "firefox", comment: "Browse the web" };
  const other = { name: "Reader", genericName: "", keywords: [], id: "reader", comment: "Opens web pages offline" };
  assert.equal(S.appScore(firefox, "fire"), 0);
  assert.equal(S.appScore(firefox, "internet"), 6);
  assert.ok(S.appScore(firefox, "web") < S.appScore(other, "web"));
  assert.equal(S.appScore(firefox, "zzz"), -1);
});

test("rank: best first, equals in their own order unless told", () => {
  const items = ["bb", "ab", "ba", "aa", "zz"];
  const score = (s) => (s.includes("a") ? (s.startsWith("a") ? 0 : 1) : -1);
  assert.deepEqual(plain(S.rank(items, score)), ["ab", "aa", "ba"]);
  assert.deepEqual(plain(S.rank(items, score, (x, y) => x.localeCompare(y))), ["aa", "ab", "ba"]);
});

test("matchCommands: what was typed, then the commands starting with it, then the rest", () => {
  const cmds = ["git", "gitk", "legit", "ls", "lsblk"];
  assert.deepEqual(plain(S.matchCommands(cmds, "git", 50)), ["git", "gitk", "legit"]);
  assert.deepEqual(plain(S.matchCommands(cmds, " ls -la ", 50)), ["ls -la"]);
  assert.deepEqual(plain(S.matchCommands(cmds, "", 50)), cmds);
  assert.deepEqual(plain(S.matchCommands(cmds, "l", 2)), ["l", "legit"]);
});
