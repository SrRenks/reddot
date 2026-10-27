pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/autostart.js" as Autostart
import "Singletons"

/**
 * 起 STARTUP: stack the commands Hyprland runs at session start. The list is
 * parsed from autostart.lua, disabled entries are kept as comments, and core
 * services (watchdogs, session target, polkit, idle, clipboard and wallpaper
 * init) are read-only so the GUI cannot strand the session.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight
    rows: []

    readonly property string path: Quickshell.env("HOME") + "/.config/hypr/modules/autostart.lua"
    property string autostartText: ""
    property var entries: []
    property bool editing: false
    property int editIndex: -1
    property int editRow: -1
    property string formText: ""
    property string notice: ""

    function refresh() {
        root.autostartText = autostartReader.text();
        root.entries = Autostart.parse(root.autostartText);
    }

    function persist(text) {
        root.autostartText = text;
        writer.setText(text);
        root.refresh();
    }

    function beginAdd() {
        root.editing = true;
        root.editIndex = -1;
        root.editRow = -1;
        root.formText = "";
        root.notice = "";
    }

    function beginEdit(entry, rowIndex) {
        if (entry.core)
            return;
        root.editing = true;
        root.editIndex = entry.index;
        root.editRow = rowIndex;
        root.formText = entry.command;
        root.notice = "";
    }

    function cancel() {
        root.editing = false;
        root.editIndex = -1;
        root.editRow = -1;
        root.formText = "";
        root.notice = "";
    }

    function save() {
        var command = root.formText.trim();
        if (command.length === 0) {
            root.notice = "Enter a command.";
            return;
        }
        for (var i = 0; i < root.entries.length; i++) {
            if (root.entries[i].command === command && root.entries[i].index !== root.editIndex) {
                root.notice = "That command is already in startup.";
                return;
            }
        }
        if (root.editIndex >= 0) {
            const replaced = Autostart.replace(root.autostartText, root.editIndex, command);
            if (!replaced.ok) {
                root.notice = "Core services cannot be edited here.";
                return;
            }
            root.persist(replaced.text);
            root.notice = "Saved. It runs on the next Hyprland start.";
        } else {
            const added = Autostart.add(root.autostartText, command);
            if (!added.ok) {
                root.notice = "Could not find the autostart block.";
                return;
            }
            root.persist(added.text);
            root.notice = "Added. It runs on the next Hyprland start.";
        }
        root.editing = false;
        root.editIndex = -1;
        root.editRow = -1;
        root.formText = "";
    }

    function toggle(entry, enabled) {
        if (entry.core)
            return;
        root.persist(Autostart.setEnabled(root.autostartText, entry.index, enabled));
        root.notice = enabled ? "Enabled. It runs on the next start." : "Disabled.";
    }

    function removeEdited() {
        if (root.editRow < 0 || root.editRow >= root.entries.length)
            return;
        root.remove(root.entries[root.editRow]);
    }

    function remove(entry) {
        if (entry.core)
            return;
        root.persist(Autostart.remove(root.autostartText, entry.index));
        root.notice = "Removed.";
        root.cancel();
    }

    onOpenChanged: if (open) {
        autostartReader.reload();
        refresh();
    }

    FileView {
        id: autostartReader
        path: root.path
        blockLoading: true
        printErrors: false
        onLoaded: root.refresh()
    }

    FileView {
        id: writer
        path: root.path
        atomicWrites: true
        printErrors: false
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "起"
            title: "STARTUP"
            showBack: true
        }

        Text {
            width: parent.width
            topPadding: 4 * root.s
            bottomPadding: 8 * root.s
            text: "Commands Hyprland runs when the session starts. Core services are locked; changes apply on the next start."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9 * root.s
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.entries

            Item {
                id: row
                required property var modelData
                required property int index
                width: parent.width
                height: 48 * root.s

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2 * root.s
                    anchors.bottomMargin: 2 * root.s
                    radius: 8 * root.s
                    color: hover.containsMouse && !row.modelData.core ? Theme.frameBg : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5 * root.s
                    height: 5 * root.s
                    radius: width / 2
                    color: row.modelData.disabled ? Theme.threadBg : Theme.verm
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 14 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: actions.left
                    anchors.rightMargin: 8 * root.s
                    spacing: 2 * root.s

                    Text {
                        text: row.modelData.name
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11.5 * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Text {
                        text: row.modelData.command
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 8.5 * root.s
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * root.s

                    Text {
                        visible: row.modelData.core
                        text: "core"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 8 * root.s
                        font.weight: Font.Bold
                        font.capitalization: Font.AllUppercase
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    LinkToggle {
                        visible: !row.modelData.core
                        s: root.s
                        on: !row.modelData.disabled
                        onToggled: root.toggle(row.modelData, !on)
                    }

                    GlyphIcon {
                        visible: !row.modelData.core
                        width: 14 * root.s
                        height: 14 * root.s
                        name: "chevron-right"
                        color: Theme.faint
                        stroke: 2
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    anchors.rightMargin: actions.width + 12 * root.s
                    hoverEnabled: true
                    cursorShape: row.modelData.core ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: root.beginEdit(row.modelData, row.index)
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
                text: "+ Add command"
                onClicked: root.beginAdd()
            }
        }

        Column {
            width: parent.width
            visible: root.editing
            spacing: 0

            SettingsLabel { s: root.s; text: root.editIndex >= 0 ? "Edit command" : "New command" }

            FormField {
                id: commandField
                s: root.s
                label: "Command"
                placeholder: "kdeconnectd, flatpak run …, systemctl --user …"
                text: root.formText
                onEdited: root.formText = input.text
                onSubmitted: root.save()
            }

            Text {
                visible: root.formText.length > 0
                text: "$HOME and shell quoting are preserved."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 8.5 * root.s
                font.weight: Font.Medium
                topPadding: 4 * root.s
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
                    onClicked: root.removeEdited()
                }

                ChipButton {
                    s: root.s
                    text: "Cancel"
                    onClicked: root.cancel()
                }
            }

            Text {
                width: parent.width
                topPadding: 4 * root.s
                text: root.notice
                color: root.notice.length > 0 ? Theme.flameCore : Theme.faint
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }
        }
    }
}
