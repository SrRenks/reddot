.pragma library

/**
 * Read/write helpers for the Hyprland autostart block. Each entry is one
 * hl.exec_cmd(...) line inside hl.on("hyprland.start", ...). A disabled entry is
 * kept in place as a commented line, so the order and the user's comments survive.
 */

var CORE = [
    /cliphist-watch\.sh/,
    /hyprland-session\.target/,
    /hyprpolkitagent/,
    /watchdog\.sh (pill|lock)/,
    /hypridle/,
    /wallpaper\.sh init/,
    /setcursor/
];

function lines(text) {
    return text.split("\n");
}

function parse(text) {
    var out = [];
    var rows = lines(text);
    for (var i = 0; i < rows.length; i++) {
        var line = rows[i];
        var m = line.match(/^(\s*)(--\s*)?hl\.exec_cmd\((.*)\)\s*$/);
        if (!m)
            continue;
        var raw = m[3].trim();
        var shown = display(raw);
        out.push({
            index: i,
            line: line,
            indent: m[1],
            disabled: m[2] !== undefined,
            raw: raw,
            command: shown,
            name: name(shown),
            core: isCore(shown)
        });
    }
    return out;
}

function display(raw) {
    var s = raw.trim();
    s = s.replace(/os\.getenv\("HOME"\)\s*\.\.\s*/g, "$HOME");
    s = s.replace(/\$HOME"/g, "$HOME");
    s = s.replace(/^"(.*)"$/, "$1");
    s = s.replace(/"$/, "");
    s = s.replace(/\\"/g, '"');
    return s;
}

function name(command) {
    if (command.indexOf("kdeconnectd") >= 0) return "KDE Connect";
    if (command.indexOf("kdeconnect-indicator") >= 0) return "KDE Connect indicator";
    if (command.indexOf("cliphist-watch") >= 0) return "Clipboard watcher";
    if (command.indexOf("wallpaper.sh init") >= 0) return "Wallpaper init";
    if (command.indexOf("watchdog.sh pill") >= 0) return "Pill watchdog";
    if (command.indexOf("watchdog.sh lock") >= 0) return "Lock watchdog";
    if (command.indexOf("hyprland-session.target") >= 0) return "Session target";
    if (command.indexOf("hyprpolkitagent") >= 0) return "Polkit agent";
    if (command.indexOf("hypridle") >= 0) return "Idle daemon";
    if (command.indexOf("setcursor") >= 0) return "Cursor";
    if (command.indexOf("fastfetch") >= 0) return "Fastfetch warm-up";
    var parts = command.trim().split(/\s+/);
    var last = parts[parts.length - 1] || command;
    return last.replace(/^.*\//, "") || command;
}

function isCore(command) {
    for (var i = 0; i < CORE.length; i++)
        if (CORE[i].test(command))
            return true;
    return false;
}

function quote(command) {
    return '"' + command.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
}

function setEnabled(text, index, enabled) {
    var rows = lines(text);
    var line = rows[index];
    if (line === undefined)
        return text;
    var m = line.match(/^(\s*)(--\s*)?hl\.exec_cmd\((.*)\)\s*$/);
    if (!m || isCore(display(m[3].trim())))
        return text;
    var bin = enabled ? "" : "-- ";
    rows[index] = m[1] + bin + "hl.exec_cmd(" + m[3].trim() + ")";
    return rows.join("\n");
}

function replace(text, index, command) {
    var rows = lines(text);
    var line = rows[index];
    if (line === undefined)
        return { text: text, ok: false };
    var m = line.match(/^(\s*)(--\s*)?hl\.exec_cmd\((.*)\)\s*$/);
    if (!m)
        return { text: text, ok: false };
    if (isCore(display(m[3].trim())))
        return { text: text, ok: false };
    rows[index] = m[1] + (m[2] || "") + "hl.exec_cmd(" + quote(command) + ")";
    return { text: rows.join("\n"), ok: true };
}

function remove(text, index) {
    var rows = lines(text);
    var line = rows[index];
    if (line === undefined)
        return text;
    var m = line.match(/^(\s*)(--\s*)?hl\.exec_cmd\((.*)\)\s*$/);
    if (!m || isCore(display(m[3].trim())))
        return text;
    rows.splice(index, 1);
    return rows.join("\n");
}

function move(text, lineIndex, delta) {
    var entries = parse(text);
    var pos = -1;
    for (var i = 0; i < entries.length; i++) {
        if (entries[i].index === lineIndex) {
            pos = i;
            break;
        }
    }
    var target = pos + delta;
    if (pos < 0 || target < 0 || target >= entries.length)
        return { text: text, ok: false, reason: "edge" };
    if (entries[pos].core || entries[target].core)
        return { text: text, ok: false, reason: "core" };
    var rows = lines(text);
    var a = entries[pos].index;
    var b = entries[target].index;
    var swap = rows[a];
    rows[a] = rows[b];
    rows[b] = swap;
    return { text: rows.join("\n"), ok: true };
}

function add(text, command) {
    var rows = lines(text);
    var start = -1;
    for (var i = 0; i < rows.length; i++) {
        if (rows[i].indexOf('hl.on("hyprland.start"') >= 0) {
            start = i;
            break;
        }
    }
    if (start < 0)
        return { text: text, ok: false };
    var at = rows.length;
    for (var j = start + 1; j < rows.length; j++) {
        if (/^\s*end\)\s*$/.test(rows[j])) {
            at = j;
            break;
        }
    }
    rows.splice(at, 0, "    hl.exec_cmd(" + quote(command) + ")");
    return { text: rows.join("\n"), ok: true };
}
