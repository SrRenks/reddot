import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const b = require("./biosUpdate.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual), e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}
function ok(cond, msg) { eq(!!cond, true, msg); }

const catalog = `<?xml version="1.0"?><packages count="2">
<package><location>https://download.lenovo.com/pccbbs/mobiles/r2zer02w_2_.xml</location><category>Networking LAN Ethernet</category></package>
<package><location>https://download.lenovo.com/pccbbs/mobiles/r2zuj38w_2_.xml</location><category>BIOS UEFI</category></package>
</packages>`;
const descriptor = `<?xml version="1.0"?><Package name="BIOS_R2ZUJ" version="1.27"><Readme default="EN"><Name>r2zuj38w.html</Name></Readme></Package>`;

eq(b.catalogUrl("21t1"), "https://download.lenovo.com/catalog/21T1_Win11.xml", "catalog URL uses machine type");
eq(b.catalogBiosUrl(catalog), "https://download.lenovo.com/pccbbs/mobiles/r2zuj38w_2_.xml", "catalog BIOS descriptor");
eq(b.parseDescriptor(descriptor).version, "1.27", "descriptor version");
eq(b.parseDescriptor(descriptor).readme, "r2zuj38w.html", "descriptor readme");
eq(b.parseVersion("R2ZET38W (1.27 )"), [1, 27], "parse BIOS ID version");
ok(!b.isNewer("R2ZET38W (1.27 )", "1.27"), "same version is not newer");
ok(b.isNewer("R2ZET35W (1.24 )", "1.27"), "older BIOS is newer");
ok(b.catalogBiosUrl("<packages/>") === "", "empty catalog has no BIOS");
eq(b.supportPage("21T1"), "https://support.lenovo.com/us/en/downloads/DS575272", "E14 official page");
ok(b.supportPage("21XX").indexOf("support.lenovo.com") >= 0, "fallback support search");
eq(b.machineTypeFromDmi("21T1S25T00"), "21T1", "machine type from product name");
eq(b.machineTypeFromDmi("LENOVO_MT_21T1_BU_Think"), "21T1", "machine type from SKU");

if (failed) { console.log(`\n${failed} test(s) FAILED`); process.exit(1); }
console.log("\nAll tests PASSED");
