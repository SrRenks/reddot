pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Native sensor snapshot for the System surface. One short Rust scan of hwmon,
 * power_supply and the ThinkPad fan interface every two seconds while the
 * surface is open; nothing runs while closed. No Glances process.
 */
Singleton {
    id: root

    property bool open: false
    property bool available: false
    readonly property string reader: Quickshell.env("HOME") + "/.local/bin/reddot-sensors"
    property string cpuLabel: "CPU"
    property string gpuLabel: "IGPU"
    property int cpuTemp: -1
    property int gpuTemp: -1
    property int nvmeTemp: -1
    property int ram0Temp: -1
    property int ram1Temp: -1
    property int fanRpm: -1
    property int fanLevel: -1
    property real powerW: -1
    property real batteryRate: -1
    property int batteryTrend: 0
    property int powerTrend: 0
    property var list: []

    signal refreshing()
    signal refreshed()

    readonly property int fanMax: 5000
    readonly property int refreshMs: 2000

    function refresh() {
        if (sensorProc.running)
            return;
        refreshing();
        sensorProc.running = true;
    }

    function trend(previous, next) {
        if (previous < 0 || next < 0)
            return 0;
        var delta = Math.abs(next) - Math.abs(previous);
        if (Math.abs(delta) < 0.05)
            return 0;
        return delta > 0 ? 1 : -1;
    }

    function parse(text) {
        var lines = text.trim().split("\n");
        var raw = null;
        for (var i = lines.length - 1; i >= 0; i--) {
            if (lines[i].charAt(0) === "{") {
                raw = lines[i];
                break;
            }
        }
        if (!raw)
            return;
        var body;
        try {
            body = JSON.parse(raw);
        } catch (e) {
            return;
        }
        var items = body.sensors || [];
        var next = {
            cpu: -1, gpu: -1, nvme: -1, ram0: -1, ram1: -1,
            rpm: -1, level: -1, power: -1, rate: -1
        };
        for (var j = 0; j < items.length; j++) {
            var item = items[j] || {};
            var label = String(item.label || "").toUpperCase();
            var value = Number(item.value);
            if (!isFinite(value))
                continue;
            if (label === "CPU" && item.type === "temperature_core") {
                next.cpu = Math.round(value);
                root.cpuLabel = item.label;
            } else if ((label === "IGPU" || label === "GPU") && item.type === "temperature_core") {
                next.gpu = Math.round(value);
                root.gpuLabel = "IGPU";
            }
            else if ((label === "SSD0" || label === "NVME") && item.type === "temperature_core")
                next.nvme = Math.round(value);
            else if (label === "RAM0")
                next.ram0 = Math.round(value);
            else if (label === "RAM1")
                next.ram1 = Math.round(value);
            else if (item.type === "fan_speed")
                // The scanner emits a dedicated FAN RPM entry and also the raw
                // hwmon fan entries. Some raw entries read 0 while the ThinkPad
                // fan is spinning, so keep the highest valid RPM instead of
                // letting the last entry overwrite the real value.
                next.rpm = Math.max(next.rpm, Math.round(value));
            else if (item.type === "fan_level")
                next.level = Math.round(value);
            else if (item.type === "amd_ppt")
                next.power = value;
            else if (item.type === "battery_power")
                next.rate = value;
        }
        root.batteryTrend = root.trend(root.batteryRate, next.rate);
        root.powerTrend = root.trend(root.powerW, next.power);
        root.cpuTemp = next.cpu;
        root.gpuTemp = next.gpu;
        root.nvmeTemp = next.nvme;
        root.ram0Temp = next.ram0;
        root.ram1Temp = next.ram1;
        root.fanRpm = next.rpm;
        root.fanLevel = next.level;
        root.powerW = next.power;
        root.batteryRate = next.rate;
        root.list = items;
        root.available = items.length > 0;
    }

    onOpenChanged: if (open) refresh()

    Timer {
        interval: root.refreshMs
        running: root.open
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: sensorProc
        command: [root.reader]
        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
        stderr: StdioCollector {}
        onExited: root.refreshed()
        // Keep the last complete snapshot if a transient sensor scan fails;
        // clearing it makes the whole sensor block disappear and reappear.
    }
}
