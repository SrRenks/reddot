import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const N = require("./navigation.js");

let failed = 0;
function ok(cond, msg) {
    if (cond) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg); }
}
function eq(actual, expected, msg) {
    ok(JSON.stringify(actual) === JSON.stringify(expected), msg);
}

const pages = N.allPageIds();
const statuses = N.allStatusIds();
const lower = (s) => String(s || "").toLowerCase();

ok(pages.length === 41, "manifest covers 41 pages");
ok(statuses.length === 14, "manifest covers 14 status items");
ok(pages.every((id) => N.pageInfo(id).title && N.pageInfo(id).sub), "every page has title and subtitle");
ok(statuses.every((id) => N.statusInfo(id).title && N.statusInfo(id).sub), "every status has title and subtitle");
ok(pages.every((id) => Array.isArray(N.pageInfo(id).aliases) && N.pageInfo(id).aliases.length > 0), "every page has aliases");

for (const id of pages) {
    const list = N.pageInfo(id).aliases.map(lower);
    ok(new Set(list).size === list.length, id + " has no duplicate aliases");
}
for (const id of statuses) {
    const list = (N.statusInfo(id).aliases || []).map(lower);
    ok(new Set(list).size === list.length, id + " has no duplicate aliases");
}

ok(N.pageInfo("bar").aliases.includes("gui"), "Bar is discoverable through gui");
ok(N.pageInfo("bar").aliases.includes("organize"), "Bar is discoverable through organize");
ok(N.pageInfo("idlelock").aliases.includes("fingerprint"), "Security is discoverable through fingerprint");
ok(N.pageInfo("thinkpad").available === "thinkpad", "ThinkPad has a hardware availability gate");
ok(N.pageInfo("bar").title === "Bar layout", "Bar title mirrors the hub label");
ok(N.statusLabel("dnd") === "Do not disturb", "status labels come from the manifest");
ok(N.pageLabel("missing") === "missing", "unknown page labels fall back to the id");

for (const group in N.settingsGroups) {
    ok(N.settingsGroups[group].every((id) => pages.includes(id)), group + " group references valid pages");
}
ok(N.settingsIndexIds().length === 10, "settings index has ten destinations");
for (const hub in N.hubs) {
    ok(N.hubs[hub].every((id) => pages.includes(id)), hub + " hub references valid pages");
}
ok(N.hubIds().length === 13, "hubs expose thirteen destinations");

for (const id of statuses) {
    const target = N.statusInfo(id).target;
    ok(!target || pages.includes(target), id + " status target is a valid page");
}
ok(N.statusInfo("dnd").action === "toggle-dnd", "DND is an action, not a page");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
