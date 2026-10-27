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

    readonly property string helper: "/usr/local/bin/reddot-thinkpad"
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

    property bool present: false
    property bool helperPresent: false
    property bool sawPresent: false
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
    property var ledsAll: []
    /** Per-LED trigger/timer metadata, keyed by sysfs LED name. */
    property var ledMeta: ({})
    /** Live brightness overrides while the surface is open (caps lock, Fn keys, firmware). */
    property var liveLeds: ({})
    /**
     * New-generation thinkpad-acpi LEDs are write-only: led_sysfs_get is only
     * registered for the legacy LED-570 path, so brightness reads 0 after a
     * successful write. Remember explicit UI writes so on/off is not inverted.
     */
    property var writtenLeds: ({})
    /** Empty unless the sysfs trigger is readable; strings from the kernel. */
    property var keyboardLangs: []
    property int lapMode: -1
    property string lidState: ""
    /** Trigger modules available to load on demand (timer/heartbeat/...). */
    property var extraTriggers: []
    property string usbCSecurity: ""
    /** True only while the ThinkPad surface is visible; drives the live LED poll. */
    property bool liveWatch: false
    property var tp: ({})
    property var curve: []
    property int doubletap: -1
    property int fnLock: -1

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
    readonly property var primaryLeds: [
        "tpacpi::kbd_backlight", "tpacpi::lid_logo_dot", "tpacpi::thinkvantage"
    ]
    readonly property var ledOther: {
        var out = [];
        for (var i = 0; i < ledsAll.length; i++) {
            if (primaryLeds.indexOf(ledsAll[i].name) < 0)
                out.push(ledsAll[i]);
        }
        return out;
    }

    function hasTp(name) {
        return tp[name] !== undefined;
    }

    /** Hardware state wins over the snapshot/UI's last write. */
    function writeOnlyLed(name) {
        return name.indexOf("tpacpi::") === 0;
    }

    function ledValue(name, fallback) {
        if (writeOnlyLed(name) && writtenLeds[name] !== undefined)
            return writtenLeds[name];
        return liveLeds[name] !== undefined ? liveLeds[name] : fallback;
    }

    function markLed(name, value) {
        var next = Object.assign({}, root.writtenLeds);
        next[name] = value;
        root.writtenLeds = next;
    }

    readonly property bool lidOpen: lidState !== "closed"

    /**
     * The power-button and lid-logo indicators are owned by the EC/firmware on
     * this model: sysfs can read 0 while the physical LED is lit. Keep the UI
     * honest by inferring those two from the machine/lid state instead of
     * presenting a false "off".
     */
    function ledOn(name, fallback) {
        if (writeOnlyLed(name) && writtenLeds[name] !== undefined)
            return writtenLeds[name] > 0;
        if (name === "tpacpi::power")
            return true;
        if (name === "tpacpi::lid_logo_dot" && lidOpen)
            return true;
        return ledValue(name, fallback) > 0;
    }

    function ledInfo(name) {
        return ledMeta[name] !== undefined ? ledMeta[name] : ({});
    }

    function applyLiveLed(name, value) {
        if (!name || isNaN(value))
            return;
        var next = Object.assign({}, root.liveLeds);
        next[name] = value;
        root.liveLeds = next;
    }

    function parseLive(text) {
        var lines = text.split("\n");
        var next = Object.assign({}, root.liveLeds);
        for (var i = 0; i < lines.length; i++) {
            var bits = lines[i].split("|");
            if (bits.length !== 2 || bits[0].length === 0)
                continue;
            var v = parseInt(bits[1], 10);
            if (!isNaN(v))
                next[bits[0]] = v;
        }
        root.liveLeds = next;
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
        sawPresent = false;
        error = "";
        statusProc.running = true;
    }

    function parseStatus(text) {
        var nextTp = ({});
        var nextLeds = ({});
        var nextLedsAll = [];
        var nextLedMeta = ({});
        var lines = text.split("\n");
        var next = {
            model: "", bios: "", fanRpm: -1, fanLevel: "", fanStatus: "",
            thinkfan: "", tempCpu: -1, tempGpu: -1, tempNvme: -1, tempAcpi: -1,
            platform: "", kbd: -1, kbdMax: 1, doubletap: -1, fnLock: -1, curve: [],
            keyboardLangs: [], lapMode: -1, lidState: "", usbCSecurity: "", extraTriggers: []
        };

        for (var i = 0; i < lines.length; i++) {
            var eq = lines[i].indexOf("=");
            if (eq < 0)
                continue;
            var k = lines[i].substring(0, eq).trim();
            var v = lines[i].substring(eq + 1).trim();
            if (k === "PRESENT") root.sawPresent = v === "1";
            else if (k === "MODEL") next.model = v;
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
            else if (k === "FN_LOCK") next.fnLock = parseInt(v, 10);
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
            else if (k === "LEDS") {
                var leds = v.split(";");
                for (var l = 0; l < leds.length; l++) {
                    var parts = leds[l].split("|");
                    if (parts.length !== 3 || parts[0].length === 0)
                        continue;
                    nextLedsAll.push({
                        name: parts[0],
                        value: parseInt(parts[1], 10),
                        max: parseInt(parts[2], 10) || 1
                    });
                }
            }
            else if (k === "LED_META") {
                var metas = v.split(";");
                for (var m = 0; m < metas.length; m++) {
                    var bits = metas[m].split("|");
                    if (bits.length < 7 || bits[0].length === 0)
                        continue;
                    nextLedMeta[bits[0]] = {
                        max: parseInt(bits[1], 10) || 1,
                        value: parseInt(bits[2], 10) || 0,
                        trigger: bits[3] || "none",
                        triggers: bits[4].length > 0 ? bits[4].split(",") : [],
                        delayOn: parseInt(bits[5], 10) || 0,
                        delayOff: parseInt(bits[6], 10) || 0
                    };
                }
            }
            else if (k === "KEYBOARD_LANGS")
                next.keyboardLangs = v.length > 0 ? v.split(/\s+/) : [];
            else if (k === "LAP_MODE") next.lapMode = parseInt(v, 10);
            else if (k === "LID_STATE") next.lidState = v;
            else if (k === "USB_C_SECURITY") next.usbCSecurity = v;
            else if (k === "LED_EXTRA_TRIGGERS")
                next.extraTriggers = v.length > 0 ? v.split(",") : [];
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
        root.fnLock = next.fnLock;
        root.leds = nextLeds;
        root.ledsAll = nextLedsAll;
        root.ledMeta = nextLedMeta;
        root.liveLeds = ({});
        root.keyboardLangs = next.keyboardLangs;
        root.lapMode = next.lapMode;
        root.lidState = next.lidState;
        root.usbCSecurity = next.usbCSecurity;
        root.extraTriggers = next.extraTriggers;
        root.tp = nextTp;
        root.curve = next.curve;
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
            const ok = code === 0 || root.sawPresent;
            root.available = ok;
            if (!ok && root.error.length === 0)
                root.error = "ThinkPad helper missing or failed (" + code + ")";
        }
    }

    /**
     * Live LED state while the surface is open. sysfs has no inotify contract
     * for LED brightness, so this is a single 500 ms read of the class directory,
     * not one watcher per LED and not a resident process. Closing the surface
     * stops the timer; the snapshot is still read on every open.
     */
    Timer {
        interval: 300
        repeat: true
        running: root.liveWatch && root.available && root.present
        onTriggered: if (!liveProc.running) liveProc.running = true
    }

    Process {
        id: liveProc
        command: ["sh", "-c",
            "for d in /sys/class/leds/*; do " +
            "[ -r \"$d/brightness\" ] || continue; " +
            "n=${d##*/}; v=$(cat \"$d/brightness\" 2>/dev/null) || continue; " +
            "echo \"$n|$v\"; done"]
        stdout: StdioCollector {
            onStreamFinished: root.parseLive(this.text)
        }
    }

    Component.onCompleted: probe.running = true
}
