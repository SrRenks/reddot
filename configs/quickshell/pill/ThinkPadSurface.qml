pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "Singletons"

/**
 * 思 THINKPAD surface. Read-only thermal/LED telemetry plus the input knobs that
 * are safe to write (TrackPoint, double-tap, keyboard backlight).
 *
 * The fan is owned by thinkfan on the reference machine, so this surface never
 * writes fan levels. It reports the EC level, RPM and the thinkfan state. Fan
 * preset switching is a separate, validated step in docs/THINKPAD.md.
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
        if (ThinkPad.tempCpu >= 0) parts.push(ThinkPad.tempCpu + " CPU");
        if (ThinkPad.tempGpu >= 0) parts.push(ThinkPad.tempGpu + " GPU");
        if (ThinkPad.tempNvme >= 0) parts.push(ThinkPad.tempNvme + " NVMe");
        return parts.join("  ·  ");
    }
    readonly property var kbdOptions: ThinkPad.kbdMax >= 2
        ? [{ label: "Off", value: 0 }, { label: "Dim", value: 1 }, { label: "Full", value: 2 }]
        : [{ label: "Off", value: 0 }, { label: "On", value: 1 }]
    readonly property var doubletapValue: ThinkPad.doubletap === 1

    property bool busy: false
    property string notice: ""

    function run(args) {
        if (actionProc.running)
            return;
        busy = true;
        notice = "";
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

    onOpenChanged: if (open) ThinkPad.refresh()

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
            root.busy = false;
            if (code === 0) {
                root.notice = "saved";
                ThinkPad.refresh();
            } else if (root.notice.length === 0) {
                root.notice = "helper failed (" + code + ")";
            }
        }
    }

    component GroupTitle: Text {
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 9 * root.s
        font.weight: Font.Bold
        font.letterSpacing: 1.2 * root.s
        font.capitalization: Font.AllUppercase
    }

    component ReadRow: Item {
        property string label: ""
        property string value: ""
        width: parent ? parent.width : 0
        height: 27 * root.s

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.weight: Font.Medium
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            width: Math.min(implicitWidth, parent.width * 0.62)
            horizontalAlignment: Text.AlignRight
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
                    ? ThinkPad.model.replace("ThinkPad ", "") + (ThinkPad.bios.length > 0 ? " · " + ThinkPad.bios : "")
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

        Item {
            width: parent.width
            height: 70 * root.s
            visible: ThinkPad.present

            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10 * root.s
                spacing: 5 * root.s

                Text {
                    text: root.fanText
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 38 * root.s
                    font.weight: Font.Bold
                    font.letterSpacing: -0.5 * root.s
                    font.features: { "tnum": 1 }
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4 * root.s
                    text: "rpm"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    font.weight: Font.DemiBold
                }
            }

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 6 * root.s
                text: root.fanState
                color: ThinkPad.thinkfan === "active" ? Theme.flameGlow : Theme.faint
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                font.weight: Font.Medium
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 13 * root.s
                text: root.sensorText
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width * 0.55)
                horizontalAlignment: Text.AlignRight
            }
        }

        Item {
            width: parent.width
            height: 118 * root.s
            visible: !ThinkPad.present

            Text {
                anchors.centerIn: parent
                text: "No ThinkPad hardware detected"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 11 * root.s
            }
        }

        Item {
            width: parent.width
            height: 88 * root.s
            visible: ThinkPad.present && !ThinkPad.available

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 14 * root.s
                text: ThinkPad.loading ? "Reading ThinkPad status…" : "ThinkPad detected, helper not available"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 34 * root.s
                text: ThinkPad.error.length > 0
                    ? ThinkPad.error
                    : "Run sudo tools/install-extras.sh from the reddot checkout"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                elide: Text.ElideRight
            }
        }

        Column {
            width: parent.width
            visible: root.showData
            spacing: 3 * root.s

            Item { width: parent.width; height: 4 * root.s }
            GroupTitle { text: "Thermal" }
            ReadRow { label: "Fan"; value: root.fanState }
            ReadRow { label: "Sensors"; value: root.sensorText }
            ReadRow {
                label: "Platform"
                value: (ThinkPad.platform.length > 0 ? ThinkPad.platform : "unknown") + " · read-only"
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.threadBg
            }

            GroupTitle { text: "Input" }

            Repeater {
                model: ThinkPad.tpList

                Item {
                    required property var modelData
                    width: parent ? parent.width : 0
                    height: 31 * root.s
                    enabled: !root.busy

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.tpLabel(parent.modelData.name)
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.Medium
                    }

                    LinkToggle {
                        visible: parent.modelData.bool
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        on: parent.modelData.value === 1
                        onToggled: root.setTp(parent.modelData.name, !on ? 1 : 0)
                    }

                    ScrubValue {
                        visible: !parent.modelData.bool
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        value: parent.modelData.value
                        from: 0
                        to: parent.modelData.max
                        step: parent.modelData.name === "drift_time" ? 50 : 4
                        enabled: !root.busy
                        onEdited: v => root.setTp(parent.modelData.name, v)
                    }
                }
            }

            Item {
                width: parent.width
                height: ThinkPad.doubletap >= 0 ? 31 * root.s : 0
                visible: ThinkPad.doubletap >= 0
                enabled: !root.busy

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Double-tap"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.Medium
                }

                LinkToggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    on: root.doubletapValue
                    onToggled: root.setDoubletap(!on)
                }
            }

            Item {
                width: parent.width
                height: ThinkPad.kbd >= 0 ? 36 * root.s : 0
                visible: ThinkPad.kbd >= 0
                enabled: !root.busy

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Keyboard light"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.Medium
                }

                SettingsSeg {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    options: root.kbdOptions
                    value: ThinkPad.kbd
                    enabled: !root.busy
                    onPicked: (v) => root.setKbd(v)
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.threadBg
            }

            GroupTitle { text: "Indicators" }

            Grid {
                id: ledGrid
                width: parent.width
                columns: 2
                spacing: 4 * root.s

                Repeater {
                    model: ThinkPad.ledList

                    Row {
                        required property var modelData
                        width: ledGrid.width / 2 - ledGrid.spacing
                        height: 20 * root.s
                        spacing: 7 * root.s

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 5 * root.s
                            height: 5 * root.s
                            radius: 2.5 * root.s
                            color: parent.modelData.value > 0 ? Theme.verm : Theme.threadBg
                            border.width: 1
                            border.color: parent.modelData.value > 0 ? Theme.vermLit : Theme.border
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.label
                            color: parent.modelData.value > 0 ? Theme.subtle : Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                        }
                    }
                }
            }

            Item { width: parent.width; height: 7 * root.s }

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

            Text {
                width: parent.width
                text: root.notice.length > 0 ? root.notice : "Fan is managed by thinkfan; temperatures only"
                color: root.notice.length > 0 ? Theme.flameCore : Theme.faint
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }
    }
}
