pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "Singletons"

/**
 * 思 THINKPAD. Lighting and Pointing; fan telemetry and the thinkfan curve
 * live in System next to the CPU/GPU/memory dials.
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
    readonly property bool hasPointing: ThinkPad.tpList.length > 0 || ThinkPad.doubletap >= 0

    property bool busy: false
    property string notice: ""
    property var actionDone: null
    property var focusRowItem: null

    function reportRowHover(row, hovered) {
        if (hovered)
            focusRowItem = row;
        else if (focusRowItem === row)
            focusRowItem = null;
    }

    function activateRow(row) {}

    function run(args, done) {
        if (actionProc.running)
            return;
        busy = true;
        notice = "authentication required…";
        actionDone = done || null;
        actionProc.command = ["/usr/bin/pkexec", root.helper].concat(args);
        actionProc.running = true;
    }

    function setTp(name, value) {
        root.run(["trackpoint", name, String(value)]);
    }

    function setDoubletap(value) {
        root.run(["doubletap", value ? "1" : "0"]);
    }

    function setFnLock(value) {
        root.run(["fnlock", value ? "1" : "0"]);
    }

    function setKbd(value) {
        root.run(["led", "kbd", String(value)]);
    }

    function setLed(name, on) {
        root.run(["led", name, on ? "1" : "0"]);
    }

    function setLedRaw(name, value) {
        root.run(["led", name, String(value)]);
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

    onOpenChanged: if (open)
        ThinkPad.refresh();

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
                root.notice = "authentication cancelled or helper failed (" + code + ")";
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

            ThinkPadLighting {
                s: root.s
                surface: root
                visible: ThinkPad.present
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

                SettingsField {
                    surface: root
                    label: "Fn lock"
                    visible: ThinkPad.fnLock >= 0

                    LinkToggle {
                        s: root.s
                        on: ThinkPad.fnLock === 1
                        enabled: !root.busy
                        onToggled: root.setFnLock(!on)
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
                        : "Changes ask for authentication; mute LEDs follow the hardware until you override them."
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
