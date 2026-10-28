#!/usr/bin/env node
/**
 * Contract for the navigation manifest. It keeps human-facing labels and
 * search aliases tied to the runtime surface catalog, so a new panel cannot
 * silently become undiscoverable and a hub cannot point at a removed surface.
 */
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const root = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const require = createRequire(import.meta.url);
const nav = require(path.join(root, "configs/quickshell/pill/lib/navigation.js"));
const failures = [];
const ok = (message) => console.log("ok   " + message);
const fail = (message) => { failures.push(message); console.log("FAIL " + message); };

const surfacesText = fs.readFileSync(path.join(root, "configs/quickshell/pill/lib/surfaces.js"), "utf8");
const catalog = new Set([...surfacesText.matchAll(/^    ([a-zA-Z0-9_]+):\s*\{/gm)].map((m) => m[1]));
const pages = new Set(nav.allPageIds());
const statusIds = new Set(nav.allStatusIds());

if (catalog.size !== 40) fail(`expected 40 catalog surfaces, found ${catalog.size}`);
for (const id of catalog) if (!pages.has(id)) fail(`catalog surface ${id} has no navigation entry`);
for (const id of pages) if (!catalog.has(id)) fail(`navigation page ${id} is not in the catalog`);
if (!failures.length) ok("catalog and navigation pages match");

const order = fs.readFileSync(path.join(root, "configs/quickshell/pill/StatusOrderList.qml"), "utf8");
const knownBlock = order.match(/knownIds:\s*\[([\s\S]*?)\]/);
const known = knownBlock ? [...knownBlock[1].matchAll(/"([^"]+)"/g)].map((m) => m[1]) : [];
if (known.length === 0) fail("StatusOrderList.qml has no knownIds");
for (const id of known) if (!statusIds.has(id)) fail(`status ${id} has no navigation entry`);
for (const id of statusIds) if (!known.includes(id)) fail(`navigation status ${id} is not in StatusOrderList.knownIds`);
if (known.length && !failures.length) ok("status order and navigation status match");

const settings = fs.readFileSync(path.join(root, "configs/quickshell/pill/Settings.qml"), "utf8");
const settingsSurfaces = [...settings.matchAll(/surface:\s*"([^"]+)"/g)].map((m) => m[1]);
for (const id of settingsSurfaces) if (!pages.has(id)) fail(`Settings.qml points at unknown page ${id}`);
for (const group in nav.settingsGroups) for (const id of nav.settingsGroups[group])
    if (!settingsSurfaces.includes(id)) fail(`settings group ${group} entry ${id} is not rendered by Settings.qml`);
if (!failures.length) ok("settings index destinations match the manifest");

const pill = fs.readFileSync(path.join(root, "configs/quickshell/pill/Pill.qml"), "utf8");
const hubSurfaces = [...pill.matchAll(/\{ name: "[^"]+", sub: "[^"]*", icon: "[^"]+", surface: "([^"]+)" \}/g)].map((m) => m[1]);
for (const id of hubSurfaces) if (!pages.has(id)) fail(`hub points at unknown page ${id}`);
for (const hub in nav.hubs) for (const id of nav.hubs[hub])
    if (!hubSurfaces.includes(id)) fail(`hub ${hub} entry ${id} is not rendered by Pill.qml`);
if (!failures.length) ok("hub destinations match the manifest");

for (const id of pages) {
    const e = nav.pageInfo(id);
    if (!e.title || !e.sub) fail(`${id} needs title and subtitle`);
    if (!Array.isArray(e.aliases) || e.aliases.length === 0) fail(`${id} needs aliases`);
    if (e.aliases.some((a) => !String(a).trim())) fail(`${id} has an empty alias`);
}
for (const id of statusIds) {
    const e = nav.statusInfo(id);
    if (!e.title || !e.sub) fail(`${id} needs title and subtitle`);
    const target = e.target || "";
    if (target && !pages.has(target)) fail(`${id} target ${target} is not a page`);
}
if (!failures.length) ok("manifest metadata is complete");

if (failures.length) {
    console.error(`\n${failures.length} navigation contract failure(s)`);
    process.exit(1);
}
console.log("\nnavigation contract passed");
