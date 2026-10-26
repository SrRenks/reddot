pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "Singletons"

/**
 * 思 THINKPAD. Three collapsible groups, in the same rhythm as Look:
 * Thermal (telemetry plus the thinkfan curve), Lighting (the LEDs that are
 * writable) and Pointing (TrackPoint and double-tap).
 *
 * The fan curve is the only fan write. It replaces the levels block in
 * /etc/thinkfan.yaml through the helper, which backs the file up and sends
 * SIGHUP. Raw levels, pwm1_enable and /proc/acpi/ibm/fan are never touched here.
 */
PillSurface {
    id: root

    mTop: 16
    mLeft: 19
    mRight: 19
    mBottom: 16

    implicitHeight: content.implicitHeight
    signal requestSurface(string name)

    readonly property string helper: ThinkPad.helper
    readonly property bool showData: ThinkPad.present && ThinkPad.available
    readonly property string fanText: ThinkPad.fanRpm >= 0 ? String(ThinkPad.fanRpm) : "—"
    readonly property string fanState: ThinkPad.thinkfan === "active"
        ? "thinkfan · level " + (ThinkPad.fanLevel.length > 0 ? ThinkPad.fanLevel : "?")
        : (ThinkPad.fanStatus.length > 0 ? "EC " + ThinkPad.fanStatus : "no fan control")
    readonly property string sensorText: {
        var parts = [];
        if (ThinkPad.tempCpu >= 0) parts.push(ThinkPad.tempCpu + "°");
        if (ThinkPad.tempGpu >= 0) parts.push(ThinkPad.tempGpu + "°");
        if (ThinkPad.tempNvme >= 0) parts.push(ThinkPad.tempNvme + "°");
        return parts.length > 0 ? parts.join("  ·  ") : "—";
    }
    readonly property bool hasLighting: ThinkPad.kbd >= 0
        || ThinkPad.leds.LIDLOGO !== undefined || ThinkPad.leds.VANTAGE !== undefined
    readonly property bool hasPointing: ThinkPad.tpList.length > 0 || ThinkPad.doubletap >= 0
    readonly property bool curveReady: ThinkPad.curve.length === 8
    readonly property string curveSummary: root.curveDirty
        ? "8 levels · edited"
        : "8 levels · thinkfan"
    readonly property var kbdOptions: ThinkPad.kbdMax >= 2
        ? [{ label: "Off", value: 0 }, { label: "Dim", value: 1 }, { label: "Full", value: 2 }]
        : [{ label: "Off", value: 0 }, { label: "On", value: 1 }]

    property bool busy: false
    property string notice: ""
    property var actionDone: null
    property var focusRowItem: null

    property bool curveOpen: false
    property var curveDraft: []
    property bool curveDirty: false

    function reportRowHover(row, hovered) {
        if (hovered)
            focusRowItem = row;
        else if (focusRowItem === row)
            focusRowItem = null;
    }

    function activateRow(row) {}

    function syncCurve(force) {
        if (!force && curveDirty)
            return;
        var next = [];
        for (var i = 0; i < ThinkPad.curve.length; i++)
            next.push({
                level: ThinkPad.curve[i].level,
                low: ThinkPad.curve[i].low,
                high: ThinkPad.curve[i].high
            });
        curveDraft = next;
    }

    function setCurve(index, edge, value) {
        if (index < 0 || index >= curveDraft.length)
            return;
        var next = curveDraft.slice();
        var item = {
            level: next[index].level,
            low: next[index].low,
            high: next[index].high
        };
        item[edge] = value;
        next[index] = item;
        curveDraft = next;
        curveDirty = true;
    }

    function applyCurve() {
        var parts = [];
        for (var i = 0; i < curveDraft.length; i++)
            parts.push(curveDraft[i].level + ":" + curveDraft[i].low + ":" + curveDraft[i].high);
        root.run(["curve", "set", parts.join(";")], function () {
            root.curveDirty = false;
            root.syncCurve(true);
        });
    }

    function run(args, done) {
        if (actionProc.running)
            return;
        busy = true;
        notice = "";
        actionDone = done || null;
        actionProc.command = ["sudo", "-n", root.helper].concat(args);
        actionProc.running = true;
    }

    function setTp(name, value) {
        root.run(["trackpoint", name, String(value)]);
    }

    function setDoubletap(value) {
        root.run(["doubletap", value ? "1" : "0"]);
    }

    function setKbd(value) {
        root.run(["led", "kbd", String(value)]);
    }

    function setLed(name, on) {
        root.run(["led", name, on ? "1" : "0"]);
    }

    function tpLabel(name) {
        switch (name) {
        case "sensitivity": return "Sensitivity";
        case "speed": return "Speed";
        case "press_to_select": return "Press to select";
        case "dragging": return "Dragging";
        case "drift_time": return "Drift time";
        case "inertia": return "Inertia";
        }
        return name;
    }

    onOpenChanged: if (open) {
        ThinkPad.refresh();
        if (!curveDirty)
            syncCurve(true);
    }

    Component.onCompleted: syncCurve(true)

    Connections {
        target: ThinkPad
        function onCurveChanged() {
            if (!root.curveDirty)
                root.syncCurve(true);
        }
    }

    Timer {
        interval: 2000
        running: root.open && ThinkPad.present && ThinkPad.available
        repeat: true
        onTriggered: ThinkPad.refresh()
    }

    Process {
        id: actionProc
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0)
                root.notice = this.text.trim()
        }
        onExited: (code) => {
            var done = root.actionDone;
            root.actionDone = null;
            root.busy = false;
            if (code === 0) {
                root.notice = "saved";
                ThinkPad.refresh();
                if (done)
                    done();
            } else if (root.notice.length === 0) {
                root.notice = "helper failed (" + code + ")";
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
            glyph: "思"
            title: "THINKPAD"
            showIcon: false

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: ThinkPad.model.length > 0
                    ? ThinkPad.model.replace("ThinkPad ", "")
                        + (ThinkPad.bios.length > 0 ? " · " + ThinkPad.bios : "")
                    : ""
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width * 0.55)
                horizontalAlignment: Text.AlignRight
            }
        }

        ThinkPadHero {
            s: root.s
            visible: ThinkPad.present
            fanText: root.fanText
            fanState: root.fanState
            sensorText: root.sensorText
        }

        ThinkPadState {
            s: root.s
            present: ThinkPad.present
            available: ThinkPad.available
            loading: ThinkPad.loading
            error: ThinkPad.error
        }

        Column {
            width: parent.width
            visible: root.showData
            spacing: 0

            ThinkPadGroup {
                s: root.s
                title: "Thermal"
                open: true

                SettingsField {
                    surface: root
                    label: "Fan"
                    visible: ThinkPad.fanRpm >= 0 || ThinkPad.thinkfan.length > 0
                    Text {
                        text: root.fanState
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.DemiBold
                    }
                }

                SettingsField {
                    surface: root
                    label: "Sensors"
                    Text {
                        text: root.sensorText
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.DemiBold
                    }
                }

                SettingsField {
                    surface: root
                    label: "Fan curve"
                    visible: root.curveReady

                    Row {
                        spacing: 8 * root.s

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.curveSummary
                            color: root.curveDirty ? Theme.flameCore : Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                            font.weight: Font.Medium
                        }

                        ChipButton {
                            s: root.s
                            text: root.curveOpen ? "Close" : "Edit"
                            enabled: !root.busy
                            onClicked: root.curveOpen = !root.curveOpen
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: root.curveOpen ? curveItem.implicitHeight : 0
                    clip: true
                    Behavior on height {
                        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
                    }

                    ThinkPadCurve {
                        id: curveItem
                        visible: root.curveOpen
                        s: root.s
                        surface: root
                        rows: root.curveDraft
                        busy: root.busy
                        dirty: root.curveDirty
                        onEdited: (index, edge, value) => root.setCurve(index, edge, value)
                        onApplied: root.applyCurve()
                        onReset: {
                            root.curveDirty = false;
                            root.syncCurve(true);
                        }
                    }
                }
            }

            ThinkPadGroup {
                s: root.s
                title: "Lighting"
                open: true
                visible: root.hasLighting

                SettingsField {
                    surface: root
                    label: "Keyboard light"
                    visible: ThinkPad.kbd >= 0

                    SettingsSeg {
                        s: root.s
                        options: root.kbdOptions
                        value: ThinkPad.kbd
                        enabled: !root.busy
                        onPicked: (v) => root.setKbd(v)
                    }
                }

                SettingsField {
                    surface: root
                    label: "Lid logo"
                    visible: ThinkPad.leds.LIDLOGO !== undefined

                    LinkToggle {
                        s: root.s
                        on: (ThinkPad.leds.LIDLOGO || 0) > 0
                        enabled: !root.busy
                        onToggled: root.setLed("lid", !on)
                    }
                }

                SettingsField {
                    surface: root
                    label: "Vantage"
                    visible: ThinkPad.leds.VANTAGE !== undefined

                    LinkToggle {
                        s: root.s
                        on: (ThinkPad.leds.VANTAGE || 0) > 0
                        enabled: !root.busy
                        onToggled: root.setLed("vantage", !on)
                    }
                }
            }

            ThinkPadGroup {
                s: root.s
                title: "Pointing"
                open: false
                accent: true
                visible: root.hasPointing

                Repeater {
                    model: ThinkPad.tpList

                    SettingsField {
                        id: tpRow
                        required property var modelData
                        surface: root
                        label: root.tpLabel(tpRow.modelData.name)

                        LinkToggle {
                            visible: tpRow.modelData.bool
                            s: root.s
                            on: tpRow.modelData.value === 1
                            enabled: !root.busy
                            onToggled: root.setTp(tpRow.modelData.name, !on ? 1 : 0)
                        }

                        ScrubValue {
                            visible: !tpRow.modelData.bool
                            s: root.s
                            value: tpRow.modelData.value
                            from: 0
                            to: tpRow.modelData.max
                            step: tpRow.modelData.name === "drift_time" ? 50 : 4
                            enabled: !root.busy
                            onEdited: (v) => root.setTp(tpRow.modelData.name, v)
                        }
                    }
                }

                SettingsField {
                    surface: root
                    label: "Double-tap"
                    visible: ThinkPad.doubletap >= 0

                    LinkToggle {
                        s: root.s
                        on: ThinkPad.doubletap === 1
                        enabled: !root.busy
                        onToggled: root.setDoubletap(!on)
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.threadBg
            }

            Item {
                width: parent.width
                height: 34 * root.s
                enabled: !root.busy

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Battery and power"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 14 * root.s
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestSurface("tlp")
                }
            }

            Item {
                width: parent.width
                height: noticeText.implicitHeight + 10 * root.s

                Text {
                    id: noticeText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 6 * root.s
                    text: root.notice.length > 0
                        ? root.notice
                        : "Mic mute, power and battery LEDs follow the hardware."
                    color: root.notice.length > 0 ? Theme.flameCore : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }
        }
    }
}
