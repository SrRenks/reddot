/**
 * Pure parsing policy for the package meter. Kept out of QML so the marker
 * protocol, last-good fallback and critical-package rules can be tested under
 * plain Node without a compositor.
 */
function isImportant(name) {
    var n = String(name || "").toLowerCase();
    if (n === "linux" || n.indexOf("linux-") === 0) return true;
    if (n === "mkinitcpio" || n.indexOf("mkinitcpio-") === 0) return true;
    if (n === "systemd" || n.indexOf("systemd-") === 0) return true;
    if (n === "glibc" || n === "gcc-libs" || n === "grub" || n === "grub-btrfs"
            || n === "systemd-boot" || n === "limine" || n === "refind"
            || n === "amd-ucode" || n === "intel-ucode"
            || n === "mesa" || n === "hyprland" || n === "quickshell")
        return true;
    if (n.indexOf("nvidia") === 0 || n.indexOf("vulkan-radeon") === 0
            || n.indexOf("vulkan-intel") === 0)
        return true;
    return false;
}

function parse(text, previous) {
    previous = previous || {};
    var off = [], aur = [], flat = [];
    var section = "";
    var states = { official: "pending", aur: "pending", flatpak: "pending" };
    var backend = "unknown";
    var errors = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.indexOf("@@BACKEND:") === 0) {
            backend = line.slice(10, line.length - 2);
            continue;
        }
        if (line === "@@OFFICIAL@@") { section = "official"; continue; }
        if (line === "@@AUR@@") { section = "aur"; continue; }
        if (line === "@@FLATPAK@@") { section = "flatpak"; continue; }
        if (line.indexOf("@@OK:") === 0) {
            states[line.slice(5, line.length - 2)] = "ok";
            continue;
        }
        if (line.indexOf("@@ERR:") === 0) {
            var errSource = line.slice(6, line.length - 2);
            states[errSource] = "error";
            errors.push(errSource);
            continue;
        }
        if (line.indexOf("@@MISSING:") === 0) {
            states[line.slice(10, line.length - 2)] = "missing";
            continue;
        }
        if (line.length === 0 || line.charAt(0) === "@@")
            continue;
        var name = line.split(/\s+/)[0];
        if (name.length === 0)
            continue;
        if (section === "official") off.push(name);
        else if (section === "aur") aur.push(name);
        else if (section === "flatpak") flat.push(name);
    }

    // A failed source keeps the previous non-empty result instead of flashing
    // a misleading zero while pacman/yay/flatpak are unavailable.
    if (states.official === "error" && (previous.official || []).length > 0)
        off = previous.official.slice();
    if (states.aur === "error" && (previous.aur || []).length > 0)
        aur = previous.aur.slice();
    if (states.flatpak === "error" && (previous.flatpak || []).length > 0)
        flat = previous.flatpak.slice();
    if (states.official === "missing") off = [];
    if (states.aur === "missing") aur = [];
    if (states.flatpak === "missing") flat = [];

    var important = [];
    for (var j = 0; j < off.length; j++)
        if (isImportant(off[j])) important.push(off[j]);
    for (var k = 0; k < aur.length; k++)
        if (isImportant(aur[k])) important.push(aur[k]);

    return {
        official: off,
        aur: aur,
        flatpak: flat,
        states: states,
        errors: errors,
        important: important,
        backend: backend,
        total: off.length + aur.length + flat.length
    };
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { isImportant, parse };
