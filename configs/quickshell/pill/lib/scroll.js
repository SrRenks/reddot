/** Pure viewport math shared by the surface base and the host wheel. */
function clampOffset(offset, contentH, viewH, delta) {
    var max = Math.max(0, contentH - viewH);
    return Math.max(0, Math.min(max, offset + delta));
}

function stepFor(angleDelta, viewH, scale) {
    var limit = Math.max(24 * scale, Math.min(160 * scale, viewH * 0.22));
    var raw = -angleDelta * 0.55;
    return Math.max(-limit, Math.min(limit, raw));
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { clampOffset, stepFor };
