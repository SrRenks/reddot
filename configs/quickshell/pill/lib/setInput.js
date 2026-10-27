.import "setDeco.js" as Deco

/** Lua field reads and writes share setDeco's word-bounded matchers. */
var getField = Deco.getField;
var setField = Deco.setField;

/**
 * Reads a field that may be written as `name =` or `["name"] =` (Hyprland's
 * dashed input options). Falls back to the plain matcher.
 */
function getKey(text, name) {
    var re = new RegExp("(?:\\[\\s*[\"']" + Deco.escapeRe(name)
        + "[\"']\\s*\\]|\\b" + Deco.escapeRe(name)
        + ")\\s*=\\s*(\"[^\"]*\"|[^,}\\n]*)");
    var m = re.exec(text);
    if (!m)
        return "";
    var v = m[1].trim();
    if (v.length >= 2 && v.charAt(0) === "\"" && v.charAt(v.length - 1) === "\"")
        return v.slice(1, -1);
    return v;
}

/** Replaces either `name =` or `["name"] =` in place. */
function setKey(text, name, valueLiteral) {
    var re = new RegExp("((?:\\[\\s*[\"']" + Deco.escapeRe(name)
        + "[\"']\\s*\\]|\\b" + Deco.escapeRe(name)
        + ")\\s*=\\s*)(\"[^\"]*\"|[^,}\\n]*)");
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "$1" + valueLiteral), ok: true };
}

/**
 * Replaces the second argument of a `hl.env("KEY", "<old>")` call with the raw
 * value, re-quoted. Returns `{ text, ok }`; ok is false when the key's env call is
 * absent.
 */
function setEnv(text, key, valueRaw) {
    var re = new RegExp("(hl\\.env\\(\\s*\"" + Deco.escapeRe(key) + "\"\\s*,\\s*)\"[^\"]*\"");
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "$1\"" + valueRaw + "\""), ok: true };
}

/**
 * Replaces the theme name and size in a `hyprctl setcursor <theme> <size>` call.
 * Returns `{ text, ok }`; ok is false when the call is absent.
 */
function setCursorLine(text, theme, size) {
    var re = /setcursor\s+\S+\s+\d+/;
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "setcursor " + theme + " " + size), ok: true };
}
