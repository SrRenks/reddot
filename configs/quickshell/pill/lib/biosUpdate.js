/**
 * Pure helpers for the ThinkPad BIOS availability check.
 *
 * Lenovo publishes a per-machine-type catalog on download.lenovo.com. The
 * catalog points at a signed package descriptor, which carries the package
 * version and readme. Keep parsing and comparison free of QML so the logic can
 * be tested without a network or a ThinkPad.
 */
function escapeXml(text) {
    return String(text || "")
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, "\"");
}

function catalogUrl(machineType) {
    return "https://download.lenovo.com/catalog/"
        + encodeURIComponent(String(machineType || "").toUpperCase()) + "_Win11.xml";
}

/** Return the descriptor URL for the BIOS UEFI package in a catalog XML. */
function catalogBiosUrl(xml) {
    var text = escapeXml(xml);
    var packages = text.match(/<package\b[\s\S]*?<\/package>/gi) || [];
    for (var i = 0; i < packages.length; i++) {
        var block = packages[i];
        if (!/<category>\s*BIOS UEFI\s*<\/category>/i.test(block))
            continue;
        var location = block.match(/<location>\s*([^<\s]+)\s*<\/location>/i);
        if (location)
            return location[1];
    }
    return "";
}

function parseDescriptor(xml) {
    var text = escapeXml(xml);
    var pkg = text.match(/<Package\b[^>]*\bversion="([^"]+)"/i);
    var readme = text.match(/<Readme\b[\s\S]*?<Name>\s*([^<]+?)\s*<\/Name>/i);
    return {
        version: pkg ? pkg[1].trim() : "",
        readme: readme ? readme[1].trim() : ""
    };
}

/** Numeric dotted version from a BIOS string such as R2ZET38W (1.27). */
function parseVersion(value) {
    var m = String(value || "").match(/(\d+)\.(\d+)/);
    if (!m)
        return [];
    var out = [parseInt(m[1], 10), parseInt(m[2], 10)];
    var rest = String(value || "").match(/\d+\.\d+\.(\d+)/);
    if (rest)
        out.push(parseInt(rest[1], 10));
    return out;
}

function compareVersions(a, b) {
    var av = Array.isArray(a) ? a : parseVersion(a);
    var bv = Array.isArray(b) ? b : parseVersion(b);
    if (av.length === 0 || bv.length === 0)
        return 0;
    var n = Math.max(av.length, bv.length);
    for (var i = 0; i < n; i++) {
        var x = av[i] || 0;
        var y = bv[i] || 0;
        if (x !== y)
            return x > y ? 1 : -1;
    }
    return 0;
}

function isNewer(current, latest) {
    return compareVersions(current, latest) < 0;
}

/**
 * Official support page for the update. 21T0/21T1 are the E14 Gen 7 and E16
 * Gen 3 families (DS575272); other machine types fall back to Lenovo's own
 * support search instead of inventing a slug.
 */
function supportPage(machineType) {
    var mt = String(machineType || "").toUpperCase();
    if (mt === "21T0" || mt === "21T1")
        return "https://support.lenovo.com/us/en/downloads/DS575272";
    return "https://support.lenovo.com/us/en/search?query="
        + encodeURIComponent(mt + " BIOS");
}

function machineTypeFromDmi(raw) {
    var text = String(raw || "").trim().toUpperCase();
    if (text.indexOf("LENOVO_MT_") === 0) {
        var mt = text.match(/LENOVO_MT_([0-9A-Z]{4})(?:_|\b)/);
        if (mt)
            return mt[1];
    }
    var direct = text.match(/^([0-9A-Z]{4})/);
    if (direct)
        return direct[1];
    var sku = text.match(/(?:^|MT_)([0-9A-Z]{4})(?:_|\b)/);
    return sku ? sku[1] : "";
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        escapeXml, catalogUrl, catalogBiosUrl, parseDescriptor, parseVersion,
        compareVersions, isNewer, supportPage, machineTypeFromDmi
    };
}
