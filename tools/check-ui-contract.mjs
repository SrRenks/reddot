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
const wheelCount = (shell.match(/\bonWheel\s*:/g) || []).length;
if (wheelCount !== 1)
    failures.push(`shell.qml: expected one backdrop wheel handler, found ${wheelCount}`);

const order = read(pillDir + "StatusOrderList.qml");
const knownBlock = order.match(/knownIds:\s*\[([\s\S]*?)\]/);
const known = knownBlock ? [...knownBlock[1].matchAll(/"([^"]+)"/g)].map((m) => m[1]) : [];
if (known.length === 0)
    failures.push("StatusOrderList.qml: knownIds is empty");
for (const id of known) {
    const hits = (order.match(new RegExp(`case "${id}"`, "g")) || []).length;
    if (hits < 3)
        failures.push(`StatusOrderList.qml: ${id} lacks label/visible/set cases`);
    const pill = read(pillDir + "Pill.qml");
    if (!pill.includes(`case "${id}":`))
        failures.push(`Pill.qml: status width is missing for ${id}`);
}
for (const id of ["weather", "updates", "settings", "power"]) {
    if (!known.includes(id))
        failures.push(`StatusOrderList.qml: ${id} is missing from knownIds`);
}

if (failures.length) {
    console.error(failures.join("\n"));
    process.exit(1);
}
console.log(`${files.length} QML files, ${ids.length} surfaces, ${known.length} status items`);
