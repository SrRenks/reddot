import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { normalize, moveItem, targetIndex } = require("./statusOrder.js");
let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual), e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log(`FAIL ${msg}\n  expected ${e}\n  got      ${a}`); }
}
const known = ["weather", "minimized", "tray", "dnd", "updates", "settings", "power"];
eq(normalize(["power", "weather", "power"], known), ["power", "weather", "minimized", "tray", "dnd", "updates", "settings"], "dedupes and appends known");
eq(normalize(["weather", "settings"], known), ["weather", "updates", "settings", "minimized", "tray", "dnd", "power"], "missing known appended and updates inserted before settings");
eq(moveItem(["a", "b", "c"], 0, 2), ["b", "c", "a"], "move down");
eq(moveItem(["a", "b", "c"], 2, 0), ["c", "a", "b"], "move up");
eq(moveItem(["a", "b"], 0, 0), ["a", "b"], "same position");
eq(moveItem(["a", "b"], 9, 0), ["a", "b"], "bad source");
eq(targetIndex(0, 0, 26, 3), 0, "first slot");
eq(targetIndex(80, 0, 26, 3), 2, "rounds to last");
eq(targetIndex(999, 0, 26, 3), 2, "clamps");
eq(targetIndex(0, 0, 26, 0), -1, "empty list");
let seed = 23;
function next() { seed = (seed * 1664525 + 1013904223) >>> 0; return seed; }
for (let i = 0; i < 300; i++) {
    const size = next() % 20;
    const order = Array.from({ length: size }, (_, n) => "id" + n);
    const from = (next() % (size + 2)) - 1;
    const to = (next() % (size + 2)) - 1;
    const moved = moveItem(order, from, to);
    if (moved.length !== size || new Set(moved).size !== size) {
        failed++;
        console.log("FAIL fuzz move changed the item set");
        break;
    }
}
if (failed) { console.log(`\n${failed} test(s) FAILED`); process.exit(1); }
console.log("\nAll tests PASSED");
