// widgets/ListNav.js: vim-style list navigation shared by the lists of Actions.
// The file is a QML library (".pragma library", global Qt), so it is loaded
// into a sandbox that provides the few Qt constants it uses.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const Qt = { Key_J: 0x4a, Key_K: 0x4b, Key_G: 0x47, Key_Down: 0x01000015, Key_Up: 0x01000013, Key_X: 0x58, ShiftModifier: 0x02000000 };
const source = fs
  .readFileSync(path.join(__dirname, "../../archlinux/.config/quickshell/widgets/ListNav.js"), "utf8")
  .replace(/^\.pragma .*$/m, "");
const sandbox = vm.createContext({ Qt });
vm.runInContext(source, sandbox);
const step = sandbox.step;

const press = (key, modifiers = 0) => ({ key, modifiers });

test("j and Down move to the next row and stop at the last one", () => {
  for (const key of [Qt.Key_J, Qt.Key_Down]) {
    assert.equal(step(press(key), 5, 0), 1);
    assert.equal(step(press(key), 5, 3), 4);
    assert.equal(step(press(key), 5, 4), 4);
  }
});

test("k and Up move to the previous row and stop at the first one", () => {
  for (const key of [Qt.Key_K, Qt.Key_Up]) {
    assert.equal(step(press(key), 5, 4), 3);
    assert.equal(step(press(key), 5, 1), 0);
    assert.equal(step(press(key), 5, 0), 0);
  }
});

test("g jumps to the top and G to the bottom", () => {
  assert.equal(step(press(Qt.Key_G), 5, 3), 0);
  assert.equal(step(press(Qt.Key_G, Qt.ShiftModifier), 5, 1), 4);
});

test("an empty list never yields a negative or out-of-range row", () => {
  for (const key of [Qt.Key_J, Qt.Key_K, Qt.Key_Down, Qt.Key_Up]) {
    assert.equal(step(press(key), 0, 0), 0);
  }
  assert.equal(step(press(Qt.Key_G), 0, 0), 0);
  assert.equal(step(press(Qt.Key_G, Qt.ShiftModifier), 0, 0), 0);
});

test("other keys are reported as not handled", () => {
  assert.equal(step(press(Qt.Key_X), 5, 2), -1);
});
