import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const bar = require("../Singletons/barLayout.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual), e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}
function ok(cond, msg) { eq(!!cond, true, msg); }

const defs = [
    { id: "workspaces", defaultHost: "bar.left", allowedHosts: ["bar.left", "bar.right"], modes: ["widget", "icon"], defaultMode: "widget", defaultConfig: { workspaceDisplay: "dots" }, defaultOrder: 0 },
    { id: "clock", defaultHost: "bar.center", allowedHosts: ["bar.center", "bar.right"], modes: ["widget", "icon"], defaultMode: "widget", defaultOrder: 0 },
    { id: "weather", defaultHost: "bar.right", allowedHosts: ["bar.right"], modes: ["icon", "widget"], defaultMode: "icon", defaultOrder: 0, status: true },
    { id: "network", defaultHost: "bar.right", allowedHosts: ["bar.right"], modes: ["icon", "widget"], defaultMode: "icon", defaultOrder: 1, status: true },
    { id: "power", defaultHost: "bar.right", allowedHosts: ["bar.right"], modes: ["icon", "widget"], defaultMode: "icon", defaultOrder: 2, status: true },
    { id: "bar", defaultHost: "settings.catalog", allowedHosts: ["settings.catalog"], modes: ["icon", "widget"], defaultMode: "widget", defaultOrder: 0, container: true }
];

const empty = bar.makeLayout([]);
eq(bar.statusIds(empty), [], "empty layout has no status ids");

const defaults = bar.makeLayout(bar.defaultItems(defs));
eq(defaults.items.length, 5, "container is not a default instance");
eq(bar.ensureBar(defaults).items.filter((i) => i.id === "bar").length, 1, "bar container can be mounted once");
eq(bar.hostOf(bar.ensureBar(defaults), "bar"), "settings.catalog", "bar mounts in settings catalog");
eq(bar.statusIds(defaults), ["weather", "network", "power"], "default status order");
eq(bar.enabled(defaults, "weather"), true, "default is enabled");
eq(bar.mode(defaults, "clock"), "widget", "default mode");
eq(bar.hostOf(defaults, "clock"), "bar.center", "default host");
eq(bar.config(defaults, "workspaces").workspaceDisplay, "dots", "workspace display defaults to dots");
eq(bar.instancesFor(defaults, "bar.left").map((i) => i.id), ["workspaces"], "left host");

const migrated = bar.migrateFlags({
    barWorkspaces: false,
    barClock: true,
    barWeather: true,
    barNetwork: false,
    barPower: true,
    barStatusOrder: "power,weather"
}, defs);
eq(bar.enabled(migrated, "workspaces"), false, "migration keeps hidden workspaces");
eq(bar.enabled(migrated, "network"), false, "migration keeps hidden network");
eq(bar.statusIds(migrated), ["power", "weather", "network"], "migration applies saved status order");
eq(bar.instancesFor(migrated, "bar.right", false).map((i) => i.id), ["power", "weather", "network"], "migration keeps disabled items in the list");

const normalized = bar.normalize({
    version: 1,
    items: [
        { id: "weather", component: "weather", host: "bar.right", mode: "widget", order: 8, enabled: false },
        { id: "weather", component: "weather", host: "bar.right", mode: "icon", order: 1 },
        { id: "unknown", component: "unknown", host: "bar.right" },
        { id: "clock", component: "clock", host: "bogus.host", mode: "bogus" }
    ]
}, defs);
eq(normalized.items.length, 5, "normalize adds missing catalog instances");
eq(normalized.items.filter((i) => i.id === "weather").length, 1, "normalize dedupes ids");
eq(bar.enabled(normalized, "weather"), false, "normalize keeps first weather");
eq(bar.mode(normalized, "weather"), "widget", "normalize keeps first mode");
eq(bar.instancesFor(normalized, "bar.center")[0].id, "clock", "invalid host falls back to default");

const numbered = bar.setConfig(normalized, "workspaces", "workspaceDisplay", "number");
eq(bar.config(numbered, "workspaces").workspaceDisplay, "number", "setConfig updates workspace display");
eq(bar.config(normalized, "workspaces").workspaceDisplay, "dots", "setConfig does not mutate previous layout");
const preserved = bar.setConfig(numbered, "workspaces", "extra", "value");
eq(bar.config(preserved, "workspaces").workspaceDisplay, "number", "setConfig preserves existing keys");

const enabled = bar.setEnabled(normalized, "network", true);
eq(bar.enabled(enabled, "network"), true, "setEnabled on");
eq(bar.enabled(normalized, "network"), true, "setEnabled does not mutate previous layout");
const icon = bar.setMode(enabled, "power", "icon");
eq(bar.mode(icon, "power"), "icon", "setMode icon");
const badMode = bar.setMode(icon, "power", "nope");
eq(bar.mode(badMode, "power"), "icon", "invalid mode is ignored");
const widget = bar.setMode(bar.setEnabled(enabled, "weather", true), "weather", "widget");
eq(bar.instancesForMode(widget, "bar.right", "widget").map((i) => i.id), ["weather"], "widget-mode instances");
eq(bar.instancesForMode(widget, "bar.right", "icon").map((i) => i.id).indexOf("weather"), -1, "widget item leaves the icon strip");

const reordered = bar.setStatusOrder(enabled, ["network", "power", "weather"]);
eq(bar.statusIds(reordered), ["network", "power", "weather"], "setStatusOrder");
const moved = bar.moveItem(reordered, "bar.right", "weather", 0);
eq(bar.statusIds(moved), ["weather", "network", "power"], "moveItem to front");
const reversed = bar.reverseHost(moved, "bar.right");
eq(bar.statusIds(reversed), ["power", "network", "weather"], "reverseHost");

const providerDefs = defs.concat([{
    id: "command", defaultHost: "bar.right", allowedHosts: ["bar.right"],
    modes: ["icon", "widget"], defaultMode: "widget", defaultOrder: 50, optional: true
}]);
const provider = bar.normalize({ items: [{
    id: "demo", component: "command", host: "bar.right", mode: "widget",
    config: { command: ["sh", "-c", "true"], interval: 30 }
}] }, providerDefs);
eq(bar.enabled(provider, "demo"), true, "provider instance enabled");
eq(bar.find(provider, "demo").config.command, ["sh", "-c", "true"], "provider command config is preserved");
ok(bar.validate({ items: [{ id: "demo", component: "command", host: "bar.right" }] }, providerDefs).ok === false, "provider without command is rejected");
ok(bar.validate({ items: [{ id: "demo", component: "command", host: "bar.right", config: { command: ["true"], interval: 30 } }] }, providerDefs).ok, "valid provider accepted");
ok(bar.validate({ items: [{ id: "workspaces", component: "workspaces", config: { workspaceDisplay: "number" } }] }, defs).ok, "workspace number display is accepted");
ok(!bar.validate({ items: [{ id: "workspaces", component: "workspaces", config: { workspaceDisplay: "bogus" } }] }, defs).ok, "workspace display is validated");

const invalid = bar.validate({ items: [{ id: "x", component: "unknown" }] }, defs);
ok(!invalid.ok, "validate rejects unknown components");
ok(invalid.errors.length === 1, "validate names the error");
const valid = bar.validate({ items: [{ id: "clock", component: "clock" }] }, defs);
ok(valid.ok, "validate accepts a known component");

if (failed) { console.log(`\n${failed} test(s) FAILED`); process.exit(1); }
console.log("\nAll tests PASSED");
