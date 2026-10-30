pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "Singletons"

/**
 * 電 TLP surface: power profile and charge window, driven through the root
 * helper `reddot-tlp`. Status is read when the surface opens and after every
 * write; nothing polls while it is closed.
 *
 * Compatibility is the point of the layout:
 *  - one BATTERY= line per pack, with a selector when there is more than one;
 *  - TLP when installed, power-profiles-daemon for the profile when not, and
 *    raw sysfs thresholds on machines with neither;
 *  - charge_behaviour gives a Pause/Resume toggle where the firmware has one.
 *
 * Thresholds are applied live (`tlp setcharge` or sysfs) and persisted in
 * /etc/tlp.d when TLP is present. The profile switch is immediate only: TLP
 * re-applies its configured profile on the next `tlp start` or AC/BAT change.
 */
PillSurface {
    id: root

    mTop: 16
    mLeft: 19
    mRight: 19
    mBottom: 16

    implicitHeight: content.implicitHeight

    readonly property string helper: "/usr/local/bin/reddot-tlp"
    readonly property var profileOptions: [
        { label: "Perf", value: "performance" },
        { label: "Bal", value: "balanced" },
        { label: "Saver", value: "power-saver" }
    ]

    property var batteries: []
    property int batIndex: 0
    readonly property var bat: (batIndex >= 0 && batIndex < batteries.length)
        ? batteries[batIndex] : null
    readonly property bool supported: bat !== null && bat.supported === true
    readonly property bool dirty: supported
        && (startPct !== loadedStart || stopPct !== loadedStop)
    readonly property bool hasCharge: {
        for (var i = 0; i < batteries.length; i++)
            if (batteries[i].supported)
                return true;
        return false;
    }
    readonly property string toolLabel: tool === "tlp" ? "TLP"
        : (tool === "ppd" ? "PPD" : (hasCharge ? "SYSFS" : ""))
    readonly property string statsLine: {
        const parts = [];
        if (Battery.healthSupported)
            parts.push(Battery.health + "% health");
        if (bat !== null && bat.cycles.length > 0)
            parts.push(bat.cycles + " cycles");
        if (Battery.capacityWh >= 1)
            parts.push(Battery.capacityWh.toFixed(1) + " Wh");
        return parts.join("  ·  ");
    }
    readonly property var batteryOptions: {
        var out = [];
        for (var i = 0; i < batteries.length; i++)
            out.push({ label: batteries[i].name, value: batteries[i].name });
        return out;
    }

    property string tool: "none"
    property string power: ""
    property string profile: "balanced"
    property string effective: ""
    property string epp: ""
    property string gov: ""
    readonly property string liveProfile: effective.length > 0 ? effective : profile
    readonly property string segValue: {
        if (liveProfile === "performance") return "performance";
        if (liveProfile === "low-power") return "power-saver";
        return "balanced";
    }
    readonly property bool overridden: effective.length > 0 && effective !== profile
    property bool enabled: false
    property bool busy: false
    property string notice: ""
    property int startPct: 40
    property int stopPct: 80
    property int loadedStart: 40
    property int loadedStop: 80

    function selectBattery(index) {
        if (root.batteries.length === 0) {
            root.batIndex = 0;
            root.startPct = 40;
            root.stopPct = 80;
            root.loadedStart = 40;
            root.loadedStop = 80;
            return;
        }
        root.batIndex = Math.max(0, Math.min(index, root.batteries.length - 1));
        const b = root.batteries[root.batIndex];
        root.startPct = b.start;
        root.stopPct = b.stop;
        root.loadedStart = b.start;
        root.loadedStop = b.stop;
    }

    function indexOfBattery(name) {
        for (var i = 0; i < root.batteries.length; i++)
            if (root.batteries[i].name === name)
                return i;
        return 0;
    }

    function parseStatus(raw) {
        var list = [];
        var nextTool = "none";
        var nextEnabled = false;
        var nextPower = "";
        var nextProfile = "";
        var nextEffective = "";
        var nextEpp = "";
        var nextGov = "";
        var lines = raw.split("\n");
        var sawProtocol = false;

        for (var i = 0; i < lines.length; i++) {
            var eq = lines[i].indexOf("=");
            if (eq < 0)
                continue;
            var k = lines[i].substring(0, eq).trim();
            var v = lines[i].substring(eq + 1).trim();
            if (k === "TOOL") {
                sawProtocol = true;
                nextTool = v;
            } else if (k === "ENABLED") {
                nextEnabled = v === "1";
            } else if (k === "POWER") {
                nextPower = v;
            } else if (k === "PROFILE") {
                nextProfile = v;
            } else if (k === "EFFECTIVE") {
                nextEffective = v;
            } else if (k === "EPP") {
                nextEpp = v;
            } else if (k === "GOV") {
                nextGov = v;
            } else if (k === "BATTERY") {
                var f = v.split("|");
                list.push({
                    name: f[0] || "",
                    start: parseInt(f[1], 10) || 0,
                    stop: parseInt(f[2], 10) || 100,
                    cycles: f[3] || "",
                    behaviour: f[4] || "",
                    pause: f[5] === "1",
                    supported: f[6] === "1"
                });
            }
        }

        var keep = root.bat !== null ? root.bat.name : "";
        root.tool = nextTool;
        root.enabled = nextEnabled;
        root.power = nextPower;
        if (nextProfile.length > 0)
            root.profile = nextProfile;
        root.effective = nextEffective;
        root.epp = nextEpp;
        root.gov = nextGov;
        root.batteries = list;
        root.selectBattery(root.indexOfBattery(keep));
        if (!sawProtocol)
            root.notice = "helper out of date — rerun install.sh";
    }

    function refresh() {
        if (statusProc.running)
            return;
        root.busy = true;
        root.notice = "";
        statusProc.running = true;
    }
    function run(args) {
        if (actionProc.running)
            return;
        root.busy = true;
        root.notice = "authentication required…";
        actionProc.command = ["/usr/bin/pkexec", root.helper].concat(args);
        actionProc.running = true;
    }
    /** Clamp start below stop and hand the pair to the helper. */
    function applyThresholds() {
        if (!root.supported)
            return;
        var start = Math.max(0, Math.min(root.startPct, root.stopPct - 5));
        root.startPct = start;
        root.run(["set", root.bat.name, String(start), String(root.stopPct)]);
    }
    function togglePause() {
        if (root.bat === null || !root.bat.pause)
            return;
        root.run([root.bat.behaviour === "inhibit-charge" ? "resume" : "pause",
                  root.bat.name]);
    }
    function care(verb) {
        if (root.bat === null)
            return;
        root.run([verb, root.bat.name]);
    }
    onOpenChanged: if (open) root.refresh()

    // TLP's udev rule re-applies the source policy on plug/unplug. Refresh so
    // the segment follows that change instead of keeping the old override.
    Connections {
        target: Battery
        function onChargingChanged() { if (root.open && !root.busy) root.refresh(); }
        function onDischargingChanged() { if (root.open && !root.busy) root.refresh(); }
    }

    Process {
        id: statusProc
        command: [root.helper, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStatus(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0)
                root.notice = this.text.trim()
        }
        onExited: (code) => {
            root.busy = false;
            if (code === 0)
                return;
            if (root.notice.length === 0)
                root.notice = "authentication cancelled or helper failed (" + code + ")";
        }
    }

    Process {
        id: actionProc
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0)
                root.notice = this.text.trim()
        }
        onExited: (code) => {
            root.busy = false;
            if (code === 0) {
                root.refresh();
            } else if (root.notice.length === 0) {
                root.notice = "command failed (" + code + ")";
            }
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "電"
            title: "POWER"
            showIcon: false

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.toolLabel.length > 0
                    ? root.toolLabel + (root.power.length > 0 ? " · " + root.power : "")
                    : "off"
                color: root.enabled || root.hasCharge ? Theme.flameGlow : Theme.faint
                font.family: Theme.font
                font.pixelSize: Typography.size("caption", root.s)
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.1 * root.s
            }
        }

        Item {
            width: parent.width
            height: 66 * root.s

            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12 * root.s
                spacing: 5 * root.s

                Text {
                    text: root.supported ? root.startPct + "–" + root.stopPct : "—"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: Typography.size("hero", root.s)
                    font.weight: Font.Bold
                    font.letterSpacing: -0.5 * root.s
                    font.features: { "tnum": 1 }
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3 * root.s
                    text: "%"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: Typography.size("bodyLarge", root.s)
                    font.weight: Font.DemiBold
                }
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 15 * root.s
                text: root.supported ? "charge window" : "no charge control"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: Typography.size("body", root.s)
                font.weight: Font.Medium
            }
        }

        Text {
            width: parent.width
            visible: root.statsLine.length > 0
            text: root.statsLine
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: Typography.size("caption", root.s)
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Item {
            width: parent.width
            height: root.batteries.length > 1 ? 34 * root.s : 0; visible: root.batteries.length > 1

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Battery"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: Typography.size("body", root.s)
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8 * root.s
            }

            SettingsSeg {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                options: root.batteryOptions
                value: root.bat !== null ? root.bat.name : ""
                onPicked: (name) => root.selectBattery(root.indexOfBattery(name))
            }
        }

        Item {
            width: parent.width
            height: 32 * root.s

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Start"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: Typography.size("body", root.s)
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8 * root.s
            }

            ScrubValue {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                value: root.startPct
                from: 0
                to: Math.max(0, root.stopPct - 5)
                step: 5
                enabled: root.supported && !root.busy
                onEdited: (v) => root.startPct = v
            }
        }

        Item {
            width: parent.width
            height: 32 * root.s

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Stop"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: Typography.size("body", root.s)
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8 * root.s
            }

            ScrubValue {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                value: root.stopPct
                from: Math.min(100, root.startPct + 5)
                to: 100
                step: 5
                enabled: root.supported && !root.busy
                onEdited: (v) => root.stopPct = v
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.threadBg
        }

        Item {
            width: parent.width
            height: 40 * root.s

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Profile"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: Typography.size("body", root.s)
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8 * root.s
            }

            SettingsSeg {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                options: root.profileOptions
                value: root.segValue
                enabled: root.tool !== "none" && !root.busy
                onPicked: (v) => root.run(["profile", v])
            }
        }

        Row {
            width: parent.width
            topPadding: 6 * root.s
            spacing: 8 * root.s

            ChipButton {
                s: root.s
                text: "Apply"
                lit: root.dirty
                visible: root.supported
                enabled: !root.busy
                opacity: enabled ? 1 : 0.45
                onClicked: root.applyThresholds()
            }

            ChipButton {
                s: root.s
                text: root.bat !== null && root.bat.behaviour === "inhibit-charge"
                    ? "Resume" : "Pause"
                visible: root.bat !== null && root.bat.pause
                enabled: !root.busy
                opacity: enabled ? 1 : 0.45
                onClicked: root.togglePause()
            }

            ChipButton {
                s: root.s
                text: "Charge once"
                visible: root.tool === "tlp"
                enabled: !root.busy
                opacity: enabled ? 1 : 0.45
                onClicked: root.care("chargeonce")
            }

            ChipButton {
                s: root.s
                text: "Full"
                visible: root.tool === "tlp"
                enabled: !root.busy
                opacity: enabled ? 1 : 0.45
                onClicked: root.care("fullcharge")
            }
        }

        Item {
            width: parent.width
            height: noticeText.implicitHeight + 15 * root.s

            Text {
                id: noticeText
                anchors.top: parent.top
                anchors.topMargin: 11 * root.s
                anchors.left: parent.left
                anchors.right: parent.right
                text: root.notice.length > 0
                    ? root.notice
                    : (root.busy
                        ? "working…"
                        : (root.tool === "none"
                            ? (root.hasCharge ? "sysfs only · not persisted" : "no battery")
                            : (root.enabled
                                ? root.toolLabel + " active · " + root.liveProfile
                                    + (root.overridden ? " · override" : "")
                                : root.toolLabel + " installed · service inactive")))
                color: root.notice.length > 0 ? Theme.flameCore : Theme.faint
                font.family: Theme.font
                font.pixelSize: Typography.size("caption", root.s)
                font.weight: Font.Medium
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }
    }
}
