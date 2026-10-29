pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "Singletons"
import "lib/biosUpdate.js" as BiosUpdate

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
    property string biosState: "idle"
    property string biosLatest: ""
    property string biosError: ""
    readonly property bool biosUpdate: biosState === "update"
    readonly property string biosStatus: {
        if (biosState === "checking") return "Checking the official Lenovo catalog…";
        if (biosState === "update") return "BIOS " + biosLatest + " available · current " + ThinkPad.bios;
        if (biosState === "current") return "BIOS " + biosLatest + " · up to date";
        if (biosState === "error") return biosError.length > 0 ? biosError : "BIOS check failed";
        return "Check the official Lenovo catalog for this model";
    }
    readonly property var machineRows: [
        { label: "Model", value: ThinkPad.model },
        { label: "Machine type", value: ThinkPad.machineType },
        { label: "BIOS", value: ThinkPad.bios },
        { label: "Lap mode", value: ThinkPad.lapMode < 0 ? "" : (ThinkPad.lapMode === 1 ? "lap" : "desk") },
        { label: "USB-C security", value: ThinkPad.usbCSecurity }
    ]

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

    function failBios(message) {
        root.biosState = "error";
        root.biosError = message;
    }

    function checkBios() {
        if (biosCatalog.running || biosDescriptor.running)
            return;
        if (ThinkPad.machineType.length < 4) {
            root.failBios("Machine type unavailable");
            return;
        }
        root.biosState = "checking";
        root.biosLatest = "";
        root.biosError = "";
        biosCatalog.command = ["curl", "-L", "--max-time", "20", "-sS",
            BiosUpdate.catalogUrl(ThinkPad.machineType)];
        biosCatalog.running = true;
    }

    function openBiosPage() {
        var page = BiosUpdate.supportPage(ThinkPad.machineType);
        if (page.length > 0)
            Qt.openUrlExternally(page);
    }

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
        ThinkPad.setKbd(value);
    }

    function ledCanonical(name) {
        if (name === "kbd") return "tpacpi::kbd_backlight";
        if (name === "lid" || name === "lid_logo") return "tpacpi::lid_logo_dot";
        if (name === "vantage" || name === "thinkvantage") return "tpacpi::thinkvantage";
        return name;
    }

    function setLed(name, on) {
        var canonical = root.ledCanonical(name);
        root.run(["led", name, on ? "1" : "0"],
            () => ThinkPad.markLed(canonical, on ? 1 : 0));
    }

    function setLedRaw(name, value) {
        root.run(["led", name, String(value)],
            () => ThinkPad.markLed(root.ledCanonical(name), value));
    }

    function setLedTrigger(name, trigger) {
        root.run(["led-trigger", name, trigger]);
    }

    function setLedDelay(name, on, off) {
        root.run(["led-delay", name, String(on), String(off)]);
    }

    function setKeyboardLang(code) {
        root.run(["keyboard-lang", code]);
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

    onOpenChanged: {
        ThinkPad.liveWatch = open;
        if (open) {
            ThinkPad.refresh();
            if (biosState === "idle")
                Qt.callLater(root.checkBios);
        }
    }
    Component.onDestruction: ThinkPad.liveWatch = false;

    Process {
        id: biosCatalog
        stdout: StdioCollector {
            onStreamFinished: {
                var url = BiosUpdate.catalogBiosUrl(this.text);
                if (url.length === 0) {
                    root.failBios("No BIOS package in the Lenovo catalog");
                    return;
                }
                biosDescriptor.command = ["curl", "-L", "--max-time", "20", "-sS", url];
                biosDescriptor.running = true;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0)
                root.biosError = this.text.trim()
        }
        onExited: (code) => {
            if (code !== 0 && root.biosState === "checking" && root.biosError.length === 0)
                root.failBios("Lenovo catalog request failed (" + code + ")");
        }
    }

    Process {
        id: biosDescriptor
        stdout: StdioCollector {
            onStreamFinished: {
                var info = BiosUpdate.parseDescriptor(this.text);
                if (info.version.length === 0) {
                    root.failBios("BIOS descriptor has no version");
                    return;
                }
                root.biosLatest = info.version;
                if (BiosUpdate.isNewer(ThinkPad.bios, info.version))
                    root.biosState = "update";
                else
                    root.biosState = "current";
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0)
                root.biosError = this.text.trim()
        }
        onExited: (code) => {
            if (code !== 0 && root.biosState === "checking" && root.biosError.length === 0)
                root.failBios("Lenovo BIOS descriptor failed (" + code + ")");
        }
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
            icon: "laptop"
            glyphColor: "#ffffff"
            iconAccent: true
            iconAccentColor: Theme.vermLit
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
                font.pixelSize: Typography.size("caption", 1)
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

            ThinkPadGroup {
                s: root.s
                title: "BIOS"
                accent: true
                initialOpen: true
                visible: ThinkPad.present

                SettingsField {
                    surface: root
                    label: "BIOS updates"
                    icon: "download"
                    caption: root.biosStatus

                    Row {
                        spacing: 6 * root.s

                        ChipButton {
                            s: root.s
                            text: root.biosState === "checking" ? "Checking…" : "Check"
                            onClicked: root.checkBios()
                        }

                        ChipButton {
                            s: root.s
                            visible: root.biosUpdate
                            text: "Download"
                            onClicked: root.openBiosPage()
                        }
                    }
                }

                Text {
                    width: parent.width
                    leftPadding: 10 * root.s
                    rightPadding: 10 * root.s
                    topPadding: 1 * root.s
                    bottomPadding: 6 * root.s
                    text: root.biosStatus
                    color: root.biosUpdate ? Theme.vermLit
                        : (root.biosState === "error" ? Theme.flameCore : Theme.faint)
                    font.family: Theme.font
                    font.pixelSize: Typography.size("micro", root.s)
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }
            }

        Column {
            width: parent.width
            visible: root.showData
            spacing: 0

            ThinkPadLighting {
                s: root.s
                surface: root
                initialOpen: true
                visible: ThinkPad.present
            }

            ThinkPadGroup {
                s: root.s
                title: "LED engine"
                        accent: true
                visible: root.showData && ThinkPad.ledsAll.length > 0

                ThinkPadLedEditor {
                    s: root.s
                    surface: root
                }
            }

            ThinkPadGroup {
                s: root.s
                title: "Machine"
                        accent: true

                Repeater {
                    model: root.machineRows

                    SettingsField {
                        id: infoRow
                        required property var modelData
                        surface: root
                        label: infoRow.modelData.label
                        visible: infoRow.modelData.value.length > 0

                        Text {
                            text: infoRow.modelData.value
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: Typography.size("caption", root.s)
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 210 * root.s)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: ThinkPad.keyboardLangs.length > 0 ? 54 * root.s : 0
                    visible: ThinkPad.keyboardLangs.length > 0

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: "Keyboard LED language"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: Typography.size("body", root.s)
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.topMargin: 16 * root.s
                        text: "Write-only on this kernel; the active code cannot be read back."
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: Typography.size("micro", root.s)
                    }

                    ThinkPadChips {
                        s: root.s
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 30 * root.s
                        options: ThinkPad.keyboardLangs
                        onPicked: (v) => root.setKeyboardLang(v)
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
                    text: "Power settings"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: Typography.size("body", root.s)
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: Typography.size("subtitle", root.s)
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestSurface("powerhub")
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
                    font.pixelSize: Typography.size("caption", root.s)
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }
        }
    }
}
