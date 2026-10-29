/**
 * Pure placement policy for the pill's normalized bar components.
 *
 * A component describes what exists in the catalog; an instance describes where
 * one copy lives. QML owns rendering, this file owns validation, ordering and
 * the one-way migration from the legacy Flags booleans. Keeping it free of QML
 * lets the Node tests cover the schema without a compositor.
 */

const VERSION = 1;

const HOSTS = {
    "bar.left": true,
    "bar.center": true,
    "bar.right": true,
    "settings.catalog": true,
    "launcher.quick": true
};

const MODES = { icon: true, widget: true };

function definitionMap(definitions) {
    const map = {};
    for (const def of definitions || [])
        map[def.id] = def;
    return map;
}

function defaultItems(definitions) {
    const out = [];
    for (const def of definitions || []) {
        if (def.container || def.optional)
            continue;
        out.push({
            id: def.id,
            component: def.id,
            host: def.defaultHost,
            mode: def.defaultMode,
            order: def.defaultOrder || 0,
            enabled: def.defaultEnabled !== false
        });
    }
    return out;
}

function makeLayout(items) {
    return { version: VERSION, items: items.slice() };
}

function validHost(def, host) {
    if (!HOSTS[host])
        return false;
    if (!def.allowedHosts || def.allowedHosts.length === 0)
        return true;
    return def.allowedHosts.indexOf(host) >= 0;
}

function normalizeItem(item, def, fallbackOrder) {
    const rawId = item && item.id ? String(item.id) : def.id;
    return {
        id: rawId,
        component: def.id,
        host: validHost(def, item && item.host) ? item.host : def.defaultHost,
        mode: MODES[item && item.mode] && def.modes.indexOf(item.mode) >= 0
            ? item.mode : def.defaultMode,
        order: Number.isFinite(Number(item && item.order))
            ? Math.max(0, Math.round(Number(item.order))) : fallbackOrder,
        enabled: !(item && item.enabled === false),
        config: item && item.config && typeof item.config === "object" ? item.config : {}
    };
}

/**
 * Accept a persisted layout or a bare instance array. Unknown components are
 * dropped, duplicate ids keep the first occurrence, missing catalog entries are
 * appended. Every valid item gets a unique id and a known host/mode.
 */
function normalize(raw, definitions) {
    const defs = definitionMap(definitions);
    const defaults = defaultItems(definitions);
    const input = Array.isArray(raw) ? raw : (raw && Array.isArray(raw.items) ? raw.items : []);
    const seen = {};
    const items = [];
    for (const item of input) {
        const def = defs[item && (item.component || item.id)];
        if (!def)
            continue;
        const normalized = normalizeItem(item, def, items.length);
        if (seen[normalized.id])
            continue;
        seen[normalized.id] = true;
        items.push(normalized);
    }
    for (const fallback of defaults) {
        if (seen[fallback.id])
            continue;
        seen[fallback.id] = true;
        items.push(fallback);
    }
    return makeLayout(items);
}

/**
 * Legacy flags are read once when bar.json does not exist. The status order
 * string is the logical order; barStatusReverse stays a render-time flag and is
 * deliberately not baked into the instances.
 */
function migrateFlags(flags, definitions) {
    const layout = makeLayout(defaultItems(definitions));
    const enabledFlag = {
        workspaces: "barWorkspaces",
        clock: "barClock",
        weather: "barWeather",
        minimized: "barMinimized",
        tray: "barTray",
        dnd: "barDnd",
        network: "barNetwork",
        inbox: "barInbox",
        mixer: "barMixer",
        sound: "barSound",
        thinkpad: "barThinkpad",
        sysmon: "barSysmon",
        updates: "barUpdates",
        recorder: "barRecorder",
        settings: "barSettings",
        power: "barPower"
    };
    for (const item of layout.items) {
        const flag = enabledFlag[item.id];
        if (flag && flags && flags[flag] === false)
            item.enabled = false;
    }
    if (flags && typeof flags.barStatusOrder === "string" && flags.barStatusOrder.length > 0) {
        const wanted = flags.barStatusOrder.split(",").map((s) => s.trim()).filter(Boolean);
        const byId = {};
        for (const item of layout.items)
            byId[item.id] = item;
        const statuses = [];
        for (const id of wanted) {
            if (byId[id] && byId[id].host === "bar.right" && statuses.indexOf(id) < 0)
                statuses.push(id);
        }
        const fallback = layout.items.filter((item) => item.host === "bar.right");
        for (const item of fallback)
            if (statuses.indexOf(item.id) < 0)
                statuses.push(item.id);
        statuses.forEach((id, index) => { byId[id].order = index; });
    }
    return ensureBar(layout);
}

function ensureBar(layout) {
    if (find(layout, "bar"))
        return layout;
    const items = layout.items.slice();
    items.push({
        id: "bar",
        component: "bar",
        host: "settings.catalog",
        mode: "widget",
        order: 0,
        enabled: true
    });
    return makeLayout(items);
}

function find(layout, id) {
    for (const item of layout && layout.items ? layout.items : [])
        if (item.id === id)
            return item;
    return null;
}

function enabled(layout, id) {
    const item = find(layout, id);
    return item ? item.enabled : false;
}

function mode(layout, id) {
    const item = find(layout, id);
    return item ? item.mode : "";
}

function hostOf(layout, id) {
    const item = find(layout, id);
    return item ? item.host : "";
}

function update(layout, id, field, value) {
    const items = layout.items.map((item) => {
        if (item.id !== id)
            return item;
        const copy = Object.assign({}, item);
        copy[field] = value;
        return copy;
    });
    return makeLayout(items);
}

function setEnabled(layout, id, value) {
    return update(layout, id, "enabled", value !== false);
}

function setMode(layout, id, value) {
    return MODES[value] ? update(layout, id, "mode", value) : layout;
}

function setHost(layout, id, host) {
    const item = find(layout, id);
    if (!item || !HOSTS[host])
        return layout;
    return update(layout, id, "host", host);
}

function sortedFor(layout, host, enabledOnly) {
    const out = (layout && layout.items ? layout.items : [])
        .filter((item) => item.host === host && (!enabledOnly || item.enabled))
        .slice()
        .sort((a, b) => a.order - b.order);
    return out;
}

function instancesFor(layout, host, enabledOnly) {
    return sortedFor(layout, host, enabledOnly !== false);
}

function instancesForMode(layout, host, mode) {
    return sortedFor(layout, host, true).filter((item) => item.mode === mode);
}

function statusIds(layout) {
    return sortedFor(layout, "bar.right", false).map((item) => item.id);
}

function setOrder(layout, host, ids) {
    const rank = {};
    ids.forEach((id, index) => { rank[id] = index; });
    const items = layout.items.map((item) => {
        if (item.host !== host || rank[item.id] === undefined)
            return item;
        const copy = Object.assign({}, item);
        copy.order = rank[item.id];
        return copy;
    });
    return makeLayout(items);
}

function setStatusOrder(layout, ids) {
    return setOrder(layout, "bar.right", ids);
}

function moveItem(layout, host, id, target) {
    const items = sortedFor(layout, host, false);
    const from = items.findIndex((item) => item.id === id);
    if (from < 0)
        return layout;
    const to = Math.max(0, Math.min(items.length - 1, target));
    if (to === from)
        return layout;
    const order = items.map((item) => item.id);
    const moved = order.splice(from, 1)[0];
    order.splice(to, 0, moved);
    return setOrder(layout, host, order);
}

function reverseHost(layout, host) {
    return setOrder(layout, host, sortedFor(layout, host, false).map((item) => item.id).reverse());
}

function validate(raw, definitions) {
    const defs = definitionMap(definitions);
    const errors = [];
    const input = Array.isArray(raw) ? raw : (raw && Array.isArray(raw.items) ? raw.items : null);
    if (!input)
        return { ok: false, errors: ["layout must be an object with an items array"], layout: null };
    const seen = {};
    for (const item of input) {
        if (!item || !item.component) {
            errors.push("instance without component");
            continue;
        }
        if (!defs[item.component]) {
            errors.push("unknown component: " + item.component);
            continue;
        }
        if (seen[item.id || item.component])
            errors.push("duplicate instance: " + (item.id || item.component));
        seen[item.id || item.component] = true;
        if (item.component === "command") {
            var cfg = item.config || {};
            if (!Array.isArray(cfg.command) || cfg.command.length === 0
                    || cfg.command.some((part) => typeof part !== "string"))
                errors.push("command provider needs a command string array: " + (item.id || "?"));
            if (cfg.interval !== undefined && !(Number(cfg.interval) > 0))
                errors.push("command provider interval must be positive: " + (item.id || "?"));
        }
    }
    return { ok: errors.length === 0, errors, layout: errors.length === 0 ? normalize(raw, definitions) : null };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        VERSION, HOSTS, MODES, defaultItems, makeLayout, normalize, migrateFlags,
        find, enabled, mode, hostOf, setEnabled, setMode, setHost, instancesFor,
        statusIds, setOrder, setStatusOrder, moveItem, reverseHost, validate,
        instancesForMode, ensureBar
    };
}
