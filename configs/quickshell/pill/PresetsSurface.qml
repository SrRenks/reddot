pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "Singletons"

/**
 * PRESETS sub-surface. A preset is a complete TLP power snapshot: profile plus
 * charge window. The active badge is computed from a live `ricelin-tlp status`,
 * never from the last applied button or a stored default.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight
    rows: []

    readonly property string helper: "/usr/local/bin/ricelin-tlp"
    readonly property var profileOptions: [
        { label: "Performance", value: "performance" },
        { label: "Balanced", value: "balanced" },
        { label: "Saver", value: "power-saver" }
    ]

    property string currentProfile: ""
    property int currentStart: -1
    property int currentStop: -1
    property bool statusReady: false
    property bool busy: false
    property string notice: ""

    property bool editing: false
    property int editIndex: -1
    property var draft: ({ name: "", profile: "balanced", start: 80, stop: 90 })

    function refresh() {
        if (statusProc.running)
            return;
        statusReady = false;
        statusProc.running = true;
    }

    function profileLabel(value) {
        switch (value) {
        case "performance": return "Performance";
        case "balanced": return "Balanced";
        case "power-saver": return "Saver";
        }
        return value;
    }

    function summary(preset) {
        return root.profileLabel(preset.profile) + " · " + preset.start + "–" + preset.stop + "%";
    }

    function activeIndex() {
        if (!statusReady)
            return -1;
        for (var i = 0; i < PresetStore.presets.length; i++) {
            var p = PresetStore.presets[i];
            if (p.profile !== root.currentProfile)
                continue;
            if (root.currentStart >= 0 &&
                (p.start !== root.currentStart || p.stop !== root.currentStop))
                continue;
            return i;
        }
        return -1;
    }

    function applyPreset(preset) {
        if (!statusReady || busy)
            return;
        busy = true;
        notice = "authentication required…";
        actionProc.command = ["/usr/bin/pkexec", root.helper, "apply",
                              preset.profile, String(preset.start), String(preset.stop)];
        actionProc.running = true;
    }

    function newPreset() {
        draft = { name: "", profile: "balanced", start: 80, stop: 90 };
        editIndex = -1;
        editing = true;
        notice = "";
    }

    function editPreset(preset, index) {
        draft = {
            name: preset.name,
            profile: preset.profile,
            start: preset.start,
            stop: preset.stop
        };
        editIndex = index;
        editing = true;
        notice = "";
    }

    function cancelEdit() {
        editing = false;
        editIndex = -1;
        draft = ({ name: "", profile: "balanced", start: 80, stop: 90 });
        notice = "";
    }

    function save() {
        var name = nameField.input.text.trim();
        if (name.length === 0) {
            notice = "Give the preset a name.";
            return;
        }
        if (name.length > 32) {
            notice = "Name is too long (32 characters max).";
            return;
        }
        for (var i = 0; i < PresetStore.presets.length; i++) {
            if (i === editIndex)
                continue;
            if (PresetStore.presets[i].name.toLowerCase() === name.toLowerCase()) {
                notice = "That name is already used.";
                return;
            }
        }
        if (draft.start < 0 || draft.stop > 100 || draft.start >= draft.stop) {
            notice = "Start must be below stop, inside 0–100%.";
            return;
        }
        var preset = {
            name: name,
            profile: draft.profile,
            start: draft.start,
            stop: draft.stop
        };
        if (editIndex >= 0)
            PresetStore.update(editIndex, preset);
        else
            PresetStore.add(preset);
        editing = false;
        editIndex = -1;
        draft = ({ name: "", profile: "balanced", start: 80, stop: 90 });
        notice = "Saved.";
    }

    function removeCurrent() {
        if (editIndex < 0)
            return;
        PresetStore.remove(editIndex);
        cancelEdit();
        notice = "Deleted.";
    }

    onOpenChanged: if (open) refresh()

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
            if (code !== 0) {
                root.statusReady = false;
                if (root.notice.length === 0)
                    root.notice = "Power helper not installed or failed (" + code + ").";
            }
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
                root.notice = "Applied.";
                root.refresh();
            } else if (root.notice.length === 0) {
                root.notice = "Authentication cancelled or apply failed (" + code + ").";
            }
        }
    }

    function parseStatus(text) {
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (line.indexOf("PROFILE=") === 0)
                currentProfile = line.substring(8).trim();
            else if (line.indexOf("BATTERY=") === 0) {
                var bits = line.substring(8).split("|");
                if (bits.length >= 3 && currentStart < 0) {
                    currentStart = parseInt(bits[1], 10);
                    currentStop = parseInt(bits[2], 10);
                }
            }
        }
        statusReady = currentProfile.length > 0;
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "組"
            title: "PRESETS"
            showBack: true
        }

        Text {
            width: parent.width
            topPadding: 4 * root.s
            bottomPadding: 8 * root.s
            text: root.statusReady
                ? "Current: " + root.profileLabel(root.currentProfile)
                    + (root.currentStart >= 0 ? " · " + root.currentStart + "–" + root.currentStop + "%" : "")
                : "Reading current power state…"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9 * root.s
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Repeater {
            model: PresetStore.presets

            Item {
                id: presetRow
                required property var modelData
                required property int index
                width: parent.width
                height: 48 * root.s

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2 * root.s
                    anchors.bottomMargin: 2 * root.s
                    radius: 8 * root.s
                    color: presetMouse.containsMouse ? Theme.frameBg : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5 * root.s
                    height: 5 * root.s
                    radius: width / 2
                    color: root.activeIndex() === presetRow.index ? Theme.verm : Theme.threadBg
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 14 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * root.s

                    Text {
                        text: presetRow.modelData.name
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11.5 * root.s
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: root.summary(presetRow.modelData)
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.Medium
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * root.s

                    ChipButton {
                        s: root.s
                        text: "Apply"
                        enabled: root.statusReady && !root.busy
                        opacity: enabled ? 1 : 0.45
                        onClicked: root.applyPreset(presetRow.modelData)
                    }

                    GlyphIcon {
                        width: 14 * root.s
                        height: 14 * root.s
                        name: "chevron-right"
                        color: Theme.faint
                        stroke: 2
                    }
                }

                MouseArea {
                    id: presetMouse
                    anchors.fill: parent
                    anchors.rightMargin: 100 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editPreset(presetRow.modelData, presetRow.index)
                }
            }
        }

        Item {
            width: parent.width
            height: 34 * root.s

            ChipButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                text: "+ New preset"
                onClicked: root.newPreset()
            }
        }

        Column {
            width: parent.width
            visible: root.editing
            spacing: 0

            SettingsLabel { s: root.s; text: root.editIndex >= 0 ? "Edit preset" : "New preset" }

            FormField {
                id: nameField
                s: root.s
                label: "Name"
                placeholder: "Desktop, laptop, travel…"
                text: root.draft.name
                onEdited: root.draft.name = input.text
                onSubmitted: root.save()
            }

            SettingsField {
                surface: root
                label: "Power profile"

                SettingsSeg {
                    s: root.s
                    options: root.profileOptions
                    value: root.draft.profile
                    onPicked: (v) => root.draft.profile = v
                }
            }

            SettingsField {
                surface: root
                label: "Charge window"

                Row {
                    spacing: 6 * root.s

                    ScrubValue {
                        s: root.s
                        value: root.draft.start
                        from: 0
                        to: 100
                        step: 5
                        onEdited: (v) => root.draft.start = v
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "–"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                    }

                    ScrubValue {
                        s: root.s
                        value: root.draft.stop
                        from: 0
                        to: 100
                        step: 5
                        onEdited: (v) => root.draft.stop = v
                    }
                }
            }

            Row {
                width: parent.width
                height: 34 * root.s
                topPadding: 4 * root.s
                spacing: 8 * root.s

                ChipButton {
                    s: root.s
                    text: "Save"
                    lit: true
                    onClicked: root.save()
                }

                ChipButton {
                    s: root.s
                    text: "Delete"
                    danger: true
                    visible: root.editIndex >= 0
                    onClicked: root.removeCurrent()
                }

                ChipButton {
                    s: root.s
                    text: "Cancel"
                    onClicked: root.cancelEdit()
                }
            }
        }

        Text {
            width: parent.width
            text: root.notice
            color: root.notice.length > 0 ? Theme.flameCore : Theme.faint
            font.family: Theme.font
            font.pixelSize: 9 * root.s
            font.weight: Font.Medium
            elide: Text.ElideRight
            topPadding: 8 * root.s
            bottomPadding: 2 * root.s
        }
    }
}
