import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { clampOffset, stepFor } = require("./scroll.js");
let failed = 0;
function eq(actual, expected, msg) {
    if (Object.is(actual, expected)) console.log("PASS " + msg);
    else { failed++; console.log(`FAIL ${msg}: expected ${expected}, got ${actual}`); }
}
eq(clampOffset(0, 1000, 500, 120), 120, "scrolls down");
eq(clampOffset(100, 1000, 500, -250), 0, "clamps at top");
eq(clampOffset(450, 1000, 500, 500), 500, "clamps at bottom");
eq(clampOffset(0, 400, 500, 120), 0, "fits without scroll");
eq(clampOffset(0, 1000, 500, 0), 0, "zero delta");
eq(clampOffset(7, 1000, 500, -3), 4, "small reverse delta");
eq(stepFor(120, 500, 1), -66, "standard wheel scrolls up");
eq(stepFor(-120, 500, 1.25), 66, "reverse wheel at scale 1.25");
eq(stepFor(1200, 500, 1), -110, "large delta is limited");
eq(stepFor(15, 500, 1), -8.25, "high-resolution scroll");
let seed = 17;
function next() { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed; }
for (let i = 0; i < 300; i++) {
    const contentH = 100 + (next() % 2000);
    const viewH = 1 + (next() % 500);
    const offset = next() % Math.max(1, contentH);
    const delta = (next() % 4000) - 2000;
    const out = clampOffset(offset, contentH, viewH, delta);
    if (out < 0 || out > Math.max(0, contentH - viewH)) {
        failed++;
        console.log(`FAIL fuzz offset ${out} outside viewport`);
        break;
    }
    const angle = (next() % 2400) - 1200;
    const step = stepFor(angle, viewH, 0.9 + (next() % 50) / 100);
    if (Math.abs(step) > Math.max(24 * 1.4, 160 * 1.4) + 0.001) {
        failed++;
        console.log(`FAIL fuzz step ${step} outside limit`);
        break;
    }
}
if (failed) { console.log(`\n${failed} test(s) FAILED`); process.exit(1); }
console.log("\nAll tests PASSED");
