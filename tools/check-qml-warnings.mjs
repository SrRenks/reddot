import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const root = new URL("..", import.meta.url);
const rootPath = path.dirname(new URL(import.meta.url).pathname);
const baselinePath = path.join(rootPath, "qml-warning-baseline.json");

function findQmllint() {
    const candidates = [process.env.QMLLINT, "qmllint",
        "/usr/lib/qt6/bin/qmllint", "/usr/lib64/qt6/bin/qmllint"];
    for (const candidate of candidates) {
        if (!candidate) continue;
        const result = spawnSync(candidate, ["--version"], { encoding: "utf8" });
        if (result.status === 0) return candidate;
    }
    return null;
}

const qmllint = findQmllint();
if (!qmllint) {
    console.error("qmllint not found; set QMLLINT or install Qt 6 qml tools");
    process.exit(1);
}
const importPaths = ["/usr/lib/qt6/qml", "/usr/lib64/qt6/qml"]
    .filter((dir) => fs.existsSync(dir));
const update = process.argv.includes("--update");
const qmlRoots = [
    "configs/quickshell/pill",
    "configs/quickshell/lock"
];

function walk(dir) {
    const out = [];
    for (const entry of fs.readdirSync(new URL(dir + "/", root), { withFileTypes: true })) {
        const rel = dir + "/" + entry.name;
        if (entry.isDirectory()) {
            if (entry.name === "lib" || entry.name === "__pycache__") continue;
            out.push(...walk(rel));
        } else if (entry.name.endsWith(".qml")) {
            out.push(rel);
        }
    }
    return out;
}

const files = qmlRoots.flatMap(walk).sort();
const current = {};
const errors = [];
for (const file of files) {
    const result = spawnSync("/usr/lib/qt6/bin/qmllint", ["-I", "/usr/lib/qt6/qml", file], {
        cwd: new URL("..", import.meta.url),
        encoding: "utf8"
    });
    const output = (result.stdout || "") + (result.stderr || "");
    const failed = result.status !== 0;
    const messages = [];
    const lines = output.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.includes("Error:")) {
            errors.push(line.trim());
            continue;
        }
        const marker = line.indexOf("Warning:");
        if (marker < 0) continue;
        let message = line.slice(marker + "Warning:".length).trim();
        message = message.replace(/^.*?:\d+:\d+:\s*/, "").replace(/^.*?::\s*/, "");
        const next = (lines[i + 1] || "").trim();
        // The source line follows the diagnostic. Keeping it in the
        // fingerprint distinguishes two warnings of the same class in one file
        // while remaining stable when unrelated lines shift.
        if (next && !next.startsWith("Warning:") && !next.startsWith("Error:")
                && !next.startsWith("Info:") && !next.startsWith("^"))
            message += " @ " + next;
        messages.push(message);
    }
    if (failed && messages.length === 0)
        errors.push(file + ": qmllint failed without a parseable diagnostic");
    if (messages.length > 0)
        current[file] = messages.sort();
}

if (errors.length > 0) {
    console.error(errors.join("\n"));
    process.exit(1);
}

function fingerprints(messages) {
    const counts = new Map();
    for (const message of messages) {
        const n = (counts.get(message) || 0) + 1;
        counts.set(message, n);
    }
    const out = [];
    for (const [message, n] of counts)
        for (let i = 1; i <= n; i++) out.push(`${message}#${i}`);
    return out.sort();
}

const currentPrints = {};
for (const [file, messages] of Object.entries(current))
    currentPrints[file] = fingerprints(messages);

if (update) {
    fs.writeFileSync(baselinePath, JSON.stringify(currentPrints, null, 2) + "\n");
    const count = Object.values(current).reduce((n, list) => n + list.length, 0);
    console.log(`baseline updated: ${Object.keys(current).length} files, ${count} warnings`);
    process.exit(0);
}

if (!fs.existsSync(baselinePath)) {
    console.error("missing tools/qml-warning-baseline.json; run with --update");
    process.exit(1);
}

const baseline = JSON.parse(fs.readFileSync(baselinePath, "utf8"));
const added = [];
const removed = [];
for (const [file, messages] of Object.entries(currentPrints)) {
    const known = new Set(baseline[file] || []);
    for (const message of messages)
        if (!known.has(message)) added.push(`${file}: ${message}`);
}
for (const [file, messages] of Object.entries(baseline)) {
    const now = new Set(currentPrints[file] || []);
    for (const message of messages)
        if (!now.has(message)) removed.push(`${file}: ${message}`);
}

if (added.length > 0) {
    console.error("new QML warnings:\n" + added.map((line) => "  " + line).join("\n"));
    console.error("fix them or, after review, run: node tools/check-qml-warnings.mjs --update");
    process.exit(1);
}

const count = Object.values(current).reduce((n, list) => n + list.length, 0);
console.log(`${files.length} QML files, ${count} known warnings, 0 new`);
if (removed.length > 0)
    console.log(`  ${removed.length} warning(s) can be removed from the baseline; run --update after review`);
