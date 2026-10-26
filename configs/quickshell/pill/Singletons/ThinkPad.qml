pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * ThinkPad capability probe and status.
 *
 * Constructed only when the Power surface or the ThinkPad surface is opened.
 * A single `test -d` decides whether the hardware exists; on anything else the
 * singleton stays inert and no helper is called. This is what keeps the base
 * setup unchanged for non-ThinkPad machines.
 */
Singleton {
    id: root

    readonly property string helper: "/usr/local/bin/ricelin-thinkpad"
    readonly property var tpOrder: ["sensitivity", "speed", "press_to_select",
                                    "dragging", "drift_time", "inertia"]
    readonly property var ledOrder: [
        { key: "MICMUTE", label: "Mic mute" },
        { key: "MUTE", label: "Speaker" },
        { key: "LIDLOGO", label: "Lid logo" },
        { key: "POWER", label: "Power" },
        { key: "STANDBY", label: "Standby" },
        { key: "VANTAGE", label: "Vantage" }
    ]

    signal updated()

    property bool present: false
    property bool helperPresent: false
    property bool available: false
    property bool loading: false
    property string error: ""
    property string model: ""
    property string bios: ""
    property int fanRpm: -1
    property string fanLevel: ""
    property string fanStatus: ""
    property string thinkfan: ""
    property int tempCpu: -1
    property int tempGpu: -1
    property int tempNvme: -1
    property int tempAcpi: -1
    property string platform: ""
    property int kbd: -1
    property int kbdMax: 1
    property var leds: ({})
    property var tp: ({})
    property var curve: []
    property int doubletap: -1

    readonly property var tpList: {
        var out = [];
        for (var i = 0; i < tpOrder.length; i++) {
            var name = tpOrder[i];
            if (tp[name] === undefined)
                continue;
            out.push({
                name: name,
                value: tp[name],
                bool: name === "press_to_select" || name === "dragging",
                max: name === "drift_time" ? 2000 : 255
            });
        }
        return out;
    }
    readonly property var ledList: {
        var out = [];
        for (var i = 0; i < ledOrder.length; i++) {
            var item = ledOrder[i];
            if (leds[item.key] !== undefined)
                out.push({ key: item.key, label: item.label, value: leds[item.key] });
        }
        return out;
    }
    readonly property bool hasFan: fanRpm >= 0

    function hasTp(name) {
        return tp[name] !== undefined;
    }

    function refresh() {
        if (!present || statusProc.running || helperProbe.running)
            return;
        if (!helperPresent) {
            error = "ThinkPad helper not installed; run sudo tools/install-extras.sh from the reddot checkout";
            helperProbe.running = true;
            return;
        }
        loading = true;
        error = "";
        statusProc.running = true;
    }

    function parseStatus(text) {
        var nextTp = ({});
        var nextLeds = ({});
        var lines = text.split("\n");
        var next = {
            model: "", bios: "", fanRpm: -1, fanLevel: "", fanStatus: "",
            thinkfan: "", tempCpu: -1, tempGpu: -1, tempNvme: -1, tempAcpi: -1,
            platform: "", kbd: -1, kbdMax: 1, doubletap: -1, curve: []
        };

        for (var i = 0; i < lines.length; i++) {
            var eq = lines[i].indexOf("=");
            if (eq < 0)
                continue;
            var k = lines[i].substring(0, eq).trim();
            var v = lines[i].substring(eq + 1).trim();
            if (k === "MODEL") next.model = v;
            else if (k === "BIOS") next.bios = v;
            else if (k === "FAN_RPM") next.fanRpm = parseInt(v, 10);
            else if (k === "FAN_LEVEL") next.fanLevel = v;
            else if (k === "FAN_STATUS") next.fanStatus = v;
            else if (k === "THINKFAN") next.thinkfan = v;
            else if (k === "TEMP_CPU") next.tempCpu = parseInt(v, 10);
            else if (k === "TEMP_GPU") next.tempGpu = parseInt(v, 10);
            else if (k === "TEMP_NVME") next.tempNvme = parseInt(v, 10);
            else if (k === "TEMP_ACPI") next.tempAcpi = parseInt(v, 10);
            else if (k === "PLATFORM") next.platform = v;
            else if (k === "LED_KBD") next.kbd = parseInt(v, 10);
            else if (k === "LED_KBD_MAX") next.kbdMax = parseInt(v, 10) || 1;
            else if (k === "DOUBLETAP") next.doubletap = parseInt(v, 10);
            else if (k === "CURVE") {
                var parts = v.split(";");
                for (var c = 0; c < parts.length; c++) {
                    var bits = parts[c].split(":");
                    if (bits.length !== 3)
                        continue;
                    next.curve.push({
                        level: parseInt(bits[0], 10),
                        low: parseInt(bits[1], 10),
                        high: parseInt(bits[2], 10)
                    });
                }
            }
            else if (k.indexOf("LED_") === 0) nextLeds[k.substring(4)] = parseInt(v, 10);
            else if (k.indexOf("TP_") === 0)
                nextTp[k.substring(3).toLowerCase()] = parseInt(v, 10);
        }

        root.model = next.model;
        root.bios = next.bios;
        root.fanRpm = next.fanRpm;
        root.fanLevel = next.fanLevel;
        root.fanStatus = next.fanStatus;
        root.thinkfan = next.thinkfan;
        root.tempCpu = next.tempCpu;
        root.tempGpu = next.tempGpu;
        root.tempNvme = next.tempNvme;
        root.tempAcpi = next.tempAcpi;
        root.platform = next.platform;
        root.kbd = next.kbd;
        root.kbdMax = next.kbdMax;
        root.doubletap = next.doubletap;
        root.leds = nextLeds;
        root.tp = nextTp;
        root.curve = next.curve;
        root.updated();
    }

    Process {
        id: probe
        command: ["test", "-d", "/sys/devices/platform/thinkpad_acpi"]
        onExited: (code) => {
            root.present = code === 0;
            if (root.present) {
                helperProbe.running = true;
            } else {
                root.available = false;
                root.loading = false;
            }
        }
    }

    Process {
        id: helperProbe
        command: ["test", "-x", root.helper]
        onExited: (code) => {
            root.helperPresent = code === 0;
            if (code === 0) {
                root.refresh();
            } else if (root.present) {
                root.available = false;
                root.loading = false;
                root.error = "ThinkPad helper not installed; run sudo tools/install-extras.sh from the reddot checkout";
            }
        }
    }

    Process {
        id: statusProc
        command: [root.helper, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStatus(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0)
                root.error = this.text.trim()
        }
        onExited: (code) => {
            root.loading = false;
            root.available = code === 0;
            if (code !== 0 && root.error.length === 0)
                root.error = "ThinkPad helper missing or failed (" + code + ")";
        }
    }

    Component.onCompleted: probe.running = true
}
