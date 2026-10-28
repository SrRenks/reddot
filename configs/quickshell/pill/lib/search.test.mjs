import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const S = require("./search.js");

let failed = 0;
function ok(cond, msg) {
    if (cond) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg); }
}

const pages = [
    { id: "bar", title: "Bar layout", sub: "Alignment and order", aliases: ["gui", "organize", "status bar"], tags: ["bar"] },
    { id: "idlelock", title: "Security", sub: "Fingerprint and idle lock", aliases: ["fingerprint", "lock"], tags: ["security"] },
    { id: "thinkpad", title: "ThinkPad", sub: "Fan and TrackPoint", aliases: ["fan"], tags: ["hardware"] },
    { id: "input", title: "Input", sub: "Keyboard and touchpad", aliases: ["touchpad"], tags: ["input"] }
];

const ids = (q) => S.rank(pages, q).map((e) => e.id);

ok(ids("bar")[0] === "bar", "title match ranks first");
ok(ids("gui")[0] === "bar", "alias gui finds Bar");
ok(ids("organize")[0] === "bar", "alias organize finds Bar");
ok(ids("fingerprint")[0] === "idlelock", "alias fingerprint finds Security");
ok(ids("fan")[0] === "thinkpad", "alias fan finds ThinkPad");
ok(ids("orgnize")[0] === "bar", "one-edit typo finds Bar");
ok(ids("touchpad")[0] === "input", "alias touchpad finds Input");
ok(S.rank(pages, "").length === 0, "empty query returns no results");
ok(S.rank(pages, "zzz").length === 0, "no match returns no results");
ok(S.normalize("  Barra  ") === "barra", "normalization trims and lowercases");
ok(S.distance("organize", "orgnize") === 1, "distance detects one insertion");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
