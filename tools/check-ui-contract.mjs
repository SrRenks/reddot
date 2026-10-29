import fs from "node:fs";
import path from "node:path";

const root = new URL("..", import.meta.url);
const read = (p) => fs.readFileSync(new URL(p, root), "utf8");
const pillDir = "configs/quickshell/pill/";
const js = read(pillDir + "lib/surfaces.js").replace(/^\.pragma library\s*$/m, "");
const catalog = new Function(js + "\nreturn { definitions, ids, isValid };")();
const ids = catalog.ids();
const failures = [];

function walk(dir) {
    const out = [];
    for (const name of fs.readdirSync(new URL(dir, root), { withFileTypes: true })) {
        const rel = dir + name.name;
        if (name.isDirectory()) {
            if (name.name === "lib") continue;
            out.push(...walk(rel + "/"));
        } else if (name.name.endsWith(".qml")) {
            out.push(rel);
        }
    }
    return out;
}

const files = walk(pillDir);
for (const file of files) {
    const text = read(file);
    if (/console\.log\s*\(\s*["']DBG/.test(text))
        failures.push(`${file}: debug console.log left in QML`);

    for (const m of text.matchAll(/requestSurface\(\s*"([^"]+)"/g))
        if (!catalog.isValid(m[1]))
            failures.push(`${file}: requestSurface("${m[1]}") is not in the catalog`);

    for (const m of text.matchAll(/\bsurface:\s*"([^"]+)"/g))
        if (!m[1].startsWith("#") && !catalog.isValid(m[1]))
            failures.push(`${file}: surface "${m[1]}" is not in the catalog`);
}

const surfaceBase = read(pillDir + "PillSurface.qml");
if (/WheelHandler\s*\{/.test(surfaceBase)
    && !/surface\.scrollBy\(ScrollMath\.stepFor/.test(surfaceBase))
    failures.push("PillSurface.qml: WheelHandler must forward to Surface.scrollBy(ScrollMath.stepFor)");

const shell = read(pillDir + "shell.qml");
if (!/closingFromKeyboard/.test(shell))
    failures.push("shell.qml: close state must distinguish keyboard from backdrop");
if (!/function dismissPill\(\)/.test(shell))
    failures.push("shell.qml: backdrop dismiss must use the mouse-close path");
if (!/dismissPillKeyboard\(\)/.test(shell))
    failures.push("shell.qml: keyboard dismiss must use the guarded path");
if (!/closeWithAnimation\(mon, true\)/.test(shell))
    failures.push("shell.qml: keyboard close must enable the hover guard");

const sensors = read(pillDir + "Singletons/Sensors.qml");
if (!/Math\.max\(next\.rpm, Math\.round\(value\)\)/.test(sensors))
    failures.push("Sensors.qml: fan RPM must keep the highest sensor value");

const wheelCount = (shell.match(/\bonWheel\s*:/g) || []).length;
if (wheelCount !== 1)
    failures.push(`shell.qml: expected one backdrop wheel handler, found ${wheelCount}`);

const search = read(pillDir + "Search.qml");
if (!/id:\s*ids\[i\]/.test(search))
    failures.push("Search.qml: results must carry the catalog id");
if (!/root\.requestSurface\(entry\.id\)/.test(search))
    failures.push("Search.qml: result activation must pass entry.id");
if (!/function pick\(\)/.test(search))
    failures.push("Search.qml: missing pick() activation helper");

const order = read(pillDir + "StatusOrderList.qml");
const barCatalog = read(pillDir + "Singletons/BarCatalog.qml");
const barLayout = read(pillDir + "Singletons/BarLayout.qml");
const known = ["weather", "minimized", "tray", "dnd", "network", "inbox",
    "mixer", "sound", "thinkpad", "sysmon", "updates", "recorder", "settings", "power"];
if (!/BarLayout\.statusOrder/.test(order) || !/BarCatalog\.label/.test(order))
    failures.push("StatusOrderList.qml: ids/labels must come from the bar catalog and layout");
if (!/BarLayout\.setStatusOrder/.test(order) || !/BarLayout\.setEnabled/.test(order))
    failures.push("StatusOrderList.qml: order and visibility must use BarLayout");
if ((barCatalog.match(/status:\s*true/g) || []).length !== known.length)
    failures.push("BarCatalog.qml: status catalog count changed without updating the contract");
for (const id of known) {
    if (!barCatalog.includes(`id: "${id}"`))
        failures.push(`BarCatalog.qml: ${id} is missing`);
    const pill = read(pillDir + "Pill.qml");
    if (!pill.includes(`case "${id}":`))
        failures.push(`Pill.qml: status width is missing for ${id}`);
}
if (!/migrateFlags/.test(barLayout) || !/bar\.json/.test(barLayout))
    failures.push("BarLayout.qml: missing migration or persisted layout path");

if (failures.length) {
    console.error(failures.join("\n"));
    process.exit(1);
}
console.log(`${files.length} QML files, ${ids.length} surfaces, ${known.length} status items`);
