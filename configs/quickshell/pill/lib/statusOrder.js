/** Pure order and drag-target policy for the bar status list. */
function normalize(raw, known) {
    var out = [];
    var seen = {};
    for (var i = 0; i < raw.length; i++) {
        var id = raw[i];
        if (!id || seen[id]) continue;
        seen[id] = true;
        out.push(id);
    }
    for (var k = 0; k < known.length; k++)
        if (known[k] !== "updates" && !seen[known[k]]) {
            seen[known[k]] = true;
            out.push(known[k]);
        }
    var at = out.indexOf("settings");
    if (at >= 0 && !seen.updates)
        out.splice(at, 0, "updates");
    else if (!seen.updates)
        out.push("updates");
    return out;
}

function moveItem(order, from, to) {
    if (from < 0 || from >= order.length) return order.slice();
    var target = Math.max(0, Math.min(order.length - 1, to));
    var next = order.slice();
    var id = next.splice(from, 1)[0];
    next.splice(target, 0, id);
    return next;
}

function targetIndex(pointerY, grabY, slotH, count) {
    if (count <= 0) return -1;
    return Math.max(0, Math.min(count - 1, Math.round((pointerY - grabY) / slotH)));
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { normalize, moveItem, targetIndex };
