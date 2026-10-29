import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { isImportant, parse } = require("../Singletons/PackageUpdatesParser.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}
function ok(cond, msg) { eq(!!cond, true, msg); }

ok(isImportant("linux"), "kernel is critical");
ok(isImportant("linux-firmware"), "linux-* is critical");
ok(isImportant("mkinitcpio"), "mkinitcpio is critical");
ok(isImportant("grub"), "bootloader is critical");
ok(isImportant("intel-ucode"), "microcode is critical");
ok(!isImportant("vscodium-bin"), "ordinary package is not critical");
ok(!isImportant("app.zen_browser.zen"), "flatpak id is not critical");

const clean = `@@OFFICIAL@@
linux 6.18.1 -> 6.18.2 [1d]
mesa 25.0 -> 25.1 [2h]
@@OK:official@@
@@AUR@@
@@OK:aur@@
@@FLATPAK@@
app.zen_browser.zen
@@OK:flatpak@@`;
const p = parse(clean);
eq(p.states, { official: "ok", aur: "ok", flatpak: "ok" }, "all sources ok");
eq(p.total, 3, "total combines sources");
eq(p.details.length, 3, "details keep one row per package");
eq(p.details[0].source, "official", "official detail source");
eq(p.important, ["linux", "mesa"], "critical names");
eq(p.errors, [], "no errors");
eq(p.backend, "unknown", "backend defaults to unknown");

const fedora = parse(`@@BACKEND:fedora@@
@@OFFICIAL@@
foo.x86_64 1.2 updates
bar.noarch 2.0 updates
@@OK:official@@
@@MISSING:aur@@
@@MISSING:flatpak@@`);
eq(fedora.backend, "fedora", "RPM backend is reported");
eq(fedora.official, ["foo.x86_64", "bar.noarch"], "RPM listing is parsed");
eq(fedora.aur, [], "AUR is absent on RPM hosts");

const noUpdates = `@@OFFICIAL@@
@@OK:official@@
@@AUR@@
@@OK:aur@@
@@FLATPAK@@
@@OK:flatpak@@`;
const n = parse(noUpdates);
eq(n.total, 0, "empty sources total zero");
eq(n.important, [], "empty sources no critical");

const broken = `@@OFFICIAL@@
@@ERR:official@@
@@AUR@@
@@MISSING:aur@@
@@FLATPAK@@
@@ERR:flatpak@@`;
const f = parse(broken, { official: ["linux"], aur: ["old-aur"], flatpak: ["app.old"] });
eq(f.official, ["linux"], "error keeps last official count");
eq(f.aur, [], "missing yay reports zero");
eq(f.flatpak, ["app.old"], "error keeps last flatpak count");
eq(f.errors.sort(), ["flatpak", "official"], "errors named");
eq(f.states.aur, "missing", "missing is not an error");
eq(f.important, ["linux"], "preserved critical remains visible");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
