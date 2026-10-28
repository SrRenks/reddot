/**
 * Pure page search for the pill. Navigation metadata supplies aliases and tags;
 * this file only normalizes text and ranks the entries, so it is testable under
 * Node and has no QML or network dependency.
 */
function normalize(value) {
    return String(value || "")
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/[^a-z0-9]+/g, " ")
        .trim();
}

function distance(a, b) {
    var m = a.length;
    var n = b.length;
    if (m === 0) return n;
    if (n === 0) return m;
    var prev = [];
    var cur = [];
    for (var j = 0; j <= n; j++) prev[j] = j;
    for (var i = 1; i <= m; i++) {
        cur[0] = i;
        for (var k = 1; k <= n; k++) {
            var cost = a.charAt(i - 1) === b.charAt(k - 1) ? 0 : 1;
            cur[k] = Math.min(cur[k - 1] + 1, prev[k] + 1, prev[k - 1] + cost);
        }
        var swap = prev;
        prev = cur;
        cur = swap;
    }
    return prev[n];
}

function subsequence(needle, haystack) {
    var j = 0;
    for (var i = 0; i < haystack.length && j < needle.length; i++)
        if (haystack.charAt(i) === needle.charAt(j)) j++;
    return j === needle.length;
}

function scoreField(field, query) {
    var f = normalize(field);
    if (f.length === 0) return 99;
    if (f === query) return 0;
    if (f.indexOf(query) === 0) return 1;
    var words = f.split(" ");
    for (var i = 0; i < words.length; i++)
        if (words[i].indexOf(query) === 0) return 2;
    if (f.indexOf(query) !== -1) return 3;
    if (query.length >= 4 && distance(query, f) <= 1) return 5;
    if (query.length >= 6 && distance(query, f) <= 2) return 7;
    if (query.length >= 3 && subsequence(query, f)) return 9;
    return 99;
}

function scoreEntry(entry, query) {
    var best = scoreField(entry.title, query);
    var aliases = entry.aliases || [];
    for (var i = 0; i < aliases.length; i++)
        best = Math.min(best, scoreField(aliases[i], query) + 0.5);
    var tags = entry.tags || [];
    for (var j = 0; j < tags.length; j++)
        best = Math.min(best, scoreField(tags[j], query) + 1.5);
    best = Math.min(best, scoreField(entry.sub, query) + 2);
    return best;
}

function rank(entries, query, limit) {
    var q = normalize(query);
    if (q.length === 0)
        return [];
    var hits = [];
    for (var i = 0; i < entries.length; i++) {
        var s = scoreEntry(entries[i], q);
        if (s < 99)
            hits.push({ entry: entries[i], score: s });
    }
    hits.sort(function (a, b) {
        if (a.score !== b.score) return a.score - b.score;
        return String(a.entry.title).toLowerCase().localeCompare(String(b.entry.title).toLowerCase());
    });
    return hits.slice(0, limit || 8).map(function (hit) { return hit.entry; });
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { normalize, distance, subsequence, rank, scoreEntry };
