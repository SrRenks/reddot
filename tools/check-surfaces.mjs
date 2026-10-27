import fs from "node:fs";

const root = new URL("..", import.meta.url);
const read = (path) => fs.readFileSync(new URL(path, root), "utf8");
const js = read("configs/quickshell/pill/lib/surfaces.js").replace(/^\.pragma library\s*$/m, "");
const catalog = new Function(js + "\nreturn { definitions, ids, parent, settingsLike, cold, isValid };")();
const pill = read("configs/quickshell/pill/Pill.qml");

const ids = catalog.ids();
const failures = [];

if (new Set(ids).size !== ids.length)
    failures.push("duplicate catalog id");

for (const id of ids) {
    const parent = catalog.parent(id);
    if (parent && !catalog.isValid(parent))
        failures.push(`${id}: unknown parent ${parent}`);
}

const seen = new Set();
function visit(id, trail) {
    if (!id) return;
    if (seen.has(id)) return;
    if (trail.includes(id)) {
        failures.push(`parent cycle: ${trail.concat(id).join(" -> ")}`);
        return;
    }
    visit(catalog.parent(id), trail.concat(id));
    seen.add(id);
}
for (const id of ids) visit(id, []);

const openNames = new Set(
    [...pill.matchAll(/readonly property bool \w+Open: surface === "([^"]+)"/g)].map((m) => m[1])
);
for (const id of ids)
    if (!openNames.has(id))
        failures.push(`${id}: no surface === boolean in Pill.qml`);
for (const name of openNames)
    if (!catalog.isValid(name))
        failures.push(`${name}: Pill.qml bool missing from catalog`);

const coldBlock = pill.match(/readonly property var coldLoaders:\s*\(\{([\s\S]*?)\}\)/);
const coldKeys = new Set(
    coldBlock ? [...coldBlock[1].matchAll(/\b(\w+):\s*ld\w+/g)].map((m) => m[1]) : []
);
for (const id of ids)
    if (catalog.cold(id) && !coldKeys.has(id))
        failures.push(`${id}: cold surface missing from coldLoaders`);

// Every catalog loader must exist as a Loader id in Pill.qml.
const loaderIds = new Set([...pill.matchAll(/\bid:\s*(ld[A-Za-z0-9_]+)/g)].map((m) => m[1]));
for (const id of ids) {
    const loader = catalog.definitions[id].loader;
    if (!loader)
        failures.push(`${id}: missing loader id in catalog`);
    else if (!loaderIds.has(loader))
        failures.push(`${id}: loader ${loader} is absent from Pill.qml`);
}

if (failures.length) {
    console.error(failures.join("\n"));
    process.exit(1);
}

console.log(`${ids.length} surfaces, ${ids.filter(catalog.settingsLike).length} settings-like, ${ids.filter(catalog.cold).length} cold`);
