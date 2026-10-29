pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/** System package updates across native, AUR and Flatpak sources. */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    rows: [
        { item: enabledRow, kind: "toggle", get: function () { return Flags.packageUpdatesEnabled; }, set: function (v) { Flags.packageUpdatesEnabled = v; } },
        { item: intervalRow, kind: "seg", vals: [15, 30, 60, 180], get: function () { return Flags.packageCheckMinutes; }, set: function (v) { Flags.packageCheckMinutes = v; } },
        { item: checkRow, kind: "toggle", get: function () { return false; }, set: function (v) { PackageUpdates.check(); } }
    ]

    Column {
        id: content
        width: parent.width
        spacing: 0

        SettingsHeader {
            s: root.s
            icon: "download"
            glyphColor: Theme.vermLit
            title: "SYSTEM PACKAGES"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            surface: root
            name: "Available"
            sub: PackageUpdates.availabilityText
            icon: "download"

            Row {
                spacing: 7 * root.s

                Text {
                    text: PackageUpdates.backendLabel + " " + PackageUpdates.officialCount
                        + (PackageUpdates.officialState === "error" ? "!" : "")
                    visible: PackageUpdates.officialAvailable
                    color: PackageUpdates.officialState === "error" ? Theme.flameCore
                        : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                Text {
                    text: "·"
                    visible: PackageUpdates.officialAvailable
                        && (PackageUpdates.aurAvailable || PackageUpdates.flatpakAvailable)
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                }
                Text {
                    text: "AUR " + PackageUpdates.aurCount
                        + (PackageUpdates.aurState === "error" ? "!" : "")
                    visible: PackageUpdates.aurAvailable
                    color: PackageUpdates.aurState === "error" ? Theme.flameCore
                        : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                Text {
                    text: "·"
                    visible: PackageUpdates.aurAvailable && PackageUpdates.flatpakAvailable
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                }
                Text {
                    text: "Flatpak " + PackageUpdates.flatpakCount
                        + (PackageUpdates.flatpakState === "error" ? "!" : "")
                    visible: PackageUpdates.flatpakAvailable
                    color: PackageUpdates.flatpakState === "error" ? Theme.flameCore
                        : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
        }

        SettingsRow {
            surface: root
            name: "Important"
            icon: "bolt"
            Text {
                text: PackageUpdates.importantNames.length > 0
                    ? PackageUpdates.importantNames.join(" · ")
                    : "None"
                color: PackageUpdates.important ? Theme.verm : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 8.5 * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 220 * root.s)
            }
        }

        SettingsLabel { s: root.s; text: "Updates" }

        Item {
            width: parent.width
            height: 188 * root.s
            visible: PackageUpdates.details.length > 0

            ListView {
                anchors.fill: parent
                clip: true
                model: PackageUpdates.details
                spacing: 4 * root.s
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    required property var modelData
                    width: ListView.view.width
                    height: 23 * root.s

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 88 * root.s
                        text: modelData.line
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 8.5 * root.s
                        font.features: { "tnum": 1 }
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.source === "aur" ? "AUR"
                            : modelData.source === "flatpak" ? "Flatpak"
                            : PackageUpdates.backendLabel
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 7.5 * root.s
                        font.letterSpacing: 0.6 * root.s
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: PackageUpdates.details.length === 0
            text: "No pending packages in the available sources."
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 9 * root.s
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
        }

        SettingsLabel { s: root.s; text: "Schedule" }

        SettingsRow {
            id: enabledRow
            surface: root
            name: "Check automatically"
            icon: "clock"
            LinkToggle {
                s: root.s
                on: Flags.packageUpdatesEnabled
                onToggled: Flags.packageUpdatesEnabled = !Flags.packageUpdatesEnabled
            }
        }

        SettingsRow {
            id: intervalRow
            surface: root
            name: "Interval"
            icon: "stopwatch"
            SettingsSeg {
                s: root.s
                options: [
                    { label: "15m", value: 15 },
                    { label: "30m", value: 30 },
                    { label: "1h", value: 60 },
                    { label: "3h", value: 180 }
                ]
                value: Flags.packageCheckMinutes
                onPicked: v => Flags.packageCheckMinutes = v
            }
        }

        SettingsRow {
            id: checkRow
            surface: root
            name: "Check now"
            icon: "refresh"
            last: true

            MouseArea {
                width: checkText.implicitWidth + 16 * root.s
                height: 22 * root.s
                cursorShape: Qt.PointingHandCursor
                onClicked: PackageUpdates.check()
                Text {
                    id: checkText
                    anchors.centerIn: parent
                    text: PackageUpdates.checking ? "checking…" : "check"
                    color: Theme.vermLit
                    font.family: Theme.font
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.DemiBold
                }
            }
        }

        Text {
            width: parent.width
            topPadding: 8 * root.s
            text: PackageUpdates.checking ? "Checking packages…"
                : PackageUpdates.errorText.length > 0
                    ? PackageUpdates.errorText + " · " + PackageUpdates.ageText
                : (PackageUpdates.lastCheck.length > 0
                    ? "Checked " + PackageUpdates.lastCheck + " · " + PackageUpdates.ageText
                        + " · " + PackageUpdates.total + " update(s)"
                    : "Waiting for the first check")
            color: PackageUpdates.errorText.length > 0 ? Theme.flameCore : Theme.faint
            font.family: Theme.font
            font.pixelSize: 9 * root.s
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
        }

        Item { width: 1; height: 12 * root.s }
    }
}
