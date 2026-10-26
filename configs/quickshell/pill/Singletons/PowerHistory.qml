pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

/**
 * UPower's own charge/rate history, read over D-Bus.
 *
 * This is the same data source GNOME Power Statistics used: the daemon keeps
 * the history in /var/lib/upower (root-only files) and serves it through
 * GetHistory(type, timespan, resolution), which is allowed for the session user.
 * No sampler, no daemon, no file of our own: one busctl call per series when a
 * battery surface opens, cached for a minute.
 *
 * The values are percentages for `charge` and watts for `rate`; the state field
 * is UPower's device state (1 charging, 2 discharging, ...).
 */
Singleton {
    id: root

    readonly property int timespan: 86400
    readonly property int resolution: 300

    property var ratePoints: []
    property var chargePoints: []
    property bool loading: false
    property string error: ""
    property double fetchedAt: 0

    readonly property bool ready: ratePoints.length > 2
    readonly property real avg1h: meanSince(ratePoints, 3600)
    readonly property real avg6h: meanSince(ratePoints, 21600)
    readonly property real avg24h: meanSince(ratePoints, 86400)
    readonly property real peak24h: peak(ratePoints)
    readonly property var hourly: hourlyAvg(ratePoints, 24)

    function devicePath() {
        const devs = UPower.devices.values;
        for (var i = 0; i < devs.length; i++) {
            const d = devs[i];
            if (d && d.isLaptopBattery && d.nativePath)
                return "/org/freedesktop/UPower/devices/battery_" + d.nativePath;
        }
        return "";
    }

    function rows(text) {
        var out = [];
        try {
            const j = JSON.parse(text);
            if (!j.data || j.data.length === 0)
                return out;
            const list = j.data[0];
            for (var i = 0; i < list.length; i++) {
                const r = list[i];
                if (r.length >= 3)
                    out.push({ t: r[0], v: r[1], s: r[2] });
            }
        } catch (e) {
            root.error = "history parse failed";
        }
        out.sort(function(a, b) { return a.t - b.t; });
        return out;
    }

    function meanSince(points, seconds) {
        if (points.length === 0)
            return 0;
        const cut = Date.now() / 1000 - seconds;
        var sum = 0, n = 0;
        for (var i = 0; i < points.length; i++) {
            if (points[i].t >= cut) {
                sum += points[i].v;
                n++;
            }
        }
        return n > 0 ? sum / n : 0;
    }

    function peak(points) {
        var m = 0;
        for (var i = 0; i < points.length; i++)
            m = Math.max(m, points[i].v);
        return m;
    }

    /** 24 hourly buckets, oldest first; -1 when the hour has no sample. */
    function hourlyAvg(points, hours) {
        var sums = [], counts = [];
        for (var i = 0; i < hours; i++) {
            sums.push(0);
            counts.push(0);
        }
        const now = Date.now() / 1000;
        for (var j = 0; j < points.length; j++) {
            const idx = hours - 1 - Math.floor((now - points[j].t) / 3600);
            if (idx >= 0 && idx < hours) {
                sums[idx] += points[j].v;
                counts[idx]++;
            }
        }
        var out = [];
        for (var k = 0; k < hours; k++)
            out.push(counts[k] > 0 ? sums[k] / counts[k] : -1);
        return out;
    }

    function refresh() {
        if (rateProc.running || chargeProc.running)
            return;
        if (Date.now() - fetchedAt < 60000 && ready)
            return;
        const path = devicePath();
        if (path.length === 0) {
            error = "no battery history";
            return;
        }
        error = "";
        loading = true;
        rateProc.command = ["busctl", "--system", "--json=short", "call",
            "org.freedesktop.UPower", path,
            "org.freedesktop.UPower.Device", "GetHistory",
            "suu", "rate", String(timespan), String(resolution)];
        chargeProc.command = ["busctl", "--system", "--json=short", "call",
            "org.freedesktop.UPower", path,
            "org.freedesktop.UPower.Device", "GetHistory",
            "suu", "charge", String(timespan), String(resolution)];
        rateProc.running = true;
        chargeProc.running = true;
    }

    Process {
        id: rateProc
        stdout: StdioCollector {
            id: rateOut
            onStreamFinished: root.ratePoints = root.rows(this.text).filter(function(p) {
                return p.s === 2;
            })
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0)
                root.error = this.text.trim()
        }
        onExited: (code) => {
            root.fetchedAt = Date.now();
            root.loading = chargeProc.running;
            if (code !== 0 && root.error.length === 0)
                root.error = "history failed (" + code + ")";
        }
    }

    Process {
        id: chargeProc
        stdout: StdioCollector {
            id: chargeOut
            onStreamFinished: root.chargePoints = root.rows(this.text)
        }
        onExited: (code) => {
            root.loading = rateProc.running;
            if (code !== 0 && root.error.length === 0)
                root.error = "history failed (" + code + ")";
        }
    }
}
