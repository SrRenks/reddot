import fs from "node:fs";
import path from "node:path";

const root = path.dirname(path.dirname(new URL(import.meta.url).pathname));
function walkMarkdown(dir) {
    const out = [];
    for (const entry of fs.readdirSync(path.join(root, dir), { withFileTypes: true })) {
        if (entry.name === "node_modules" || entry.name === "__pycache__")
            continue;
        const rel = dir + "/" + entry.name;
        if (entry.isDirectory())
            out.push(...walkMarkdown(rel));
        else if (entry.name.endsWith(".md"))
            out.push(rel);
    }
    return out;
}

const files = [
    "README.md",
    "CHANGELOG.md",
    "WALLPAPERS.md",
    "tools/README.md",
    ...walkMarkdown("docs"),
    ...walkMarkdown("configs")
];
const required = [
    "docs/index.md",
    "docs/getting-started.md",
    "docs/architecture.md",
    "docs/repository-map.md",
    "docs/validation-checklist.md",
    "docs/roadmap.md",
    "CHANGELOG.md"
];
const failures = [];

for (const file of required)
    if (!fs.existsSync(path.join(root, file)))
        failures.push(`missing required doc: ${file}`);

for (const file of files) {
    const full = path.join(root, file);
    if (!fs.existsSync(full)) {
        failures.push(`missing markdown file: ${file}`);
        continue;
    }
    const text = fs.readFileSync(full, "utf8");
    for (const match of text.matchAll(/\[[^\]]*\]\(([^)]+)\)/g)) {
        let target = match[1].trim();
        if (target.startsWith("<") && target.endsWith(">"))
            target = target.slice(1, -1);
        if (!target || target.startsWith("#"))
            continue;
        if (/^(https?:|mailto:|file:)/i.test(target))
            continue;
        target = decodeURIComponent(target.split("#")[0].split("?")[0]);
        if (!target)
            continue;
        const resolved = path.resolve(path.dirname(full), target);
        if (!fs.existsSync(resolved))
            failures.push(`${file}: broken link ${match[1]}`);
    }
}

if (failures.length > 0) {
    console.error(failures.join("\n"));
    process.exit(1);
}
console.log(`${files.length} markdown files, ${required.length} required docs, links ok`);
