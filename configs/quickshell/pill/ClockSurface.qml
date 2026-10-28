pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/** Clock format and visibility for the top bar. */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    rows: [
        { item: timeRow, kind: "seg", vals: [false, true], get: function () { return Flags.time12h; }, set: function (v) { Flags.time12h = v; } },
        { item: secondsRow, kind: "toggle", get: function () { return Flags.clockSeconds; }, set: function (v) { Flags.clockSeconds = v; } },
        { item: clockRow, kind: "toggle", get: function () { return Flags.barClock; }, set: function (v) { Flags.barClock = v; } },
        { item: dateRow, kind: "toggle", get: function () { return Flags.barDate; }, set: function (v) { Flags.barDate = v; } }
    ]

    Column {
        id: content
        width: parent.width
        spacing: 0

        SettingsHeader {
            s: root.s
            icon: "clock"
            glyphColor: Theme.vermLit
            title: "CLOCK"
            showBack: true
        }

        SettingsRow {
            id: timeRow
            surface: root
            name: "Time format"
            icon: "clock"
            SettingsSeg {
                s: root.s
                options: [{ label: "24H", value: false }, { label: "12H", value: true }]
                value: Flags.time12h
                onPicked: v => Flags.time12h = v
            }
        }

        SettingsRow {
            id: secondsRow
            surface: root
            name: "Seconds"
            icon: "stopwatch"
            LinkToggle {
                s: root.s
                on: Flags.clockSeconds
                onToggled: Flags.clockSeconds = !Flags.clockSeconds
            }
        }

        SettingsRow {
            id: clockRow
            surface: root
            name: "Clock in bar"
            icon: "clock"
            LinkToggle {
                s: root.s
                on: Flags.barClock
                onToggled: Flags.barClock = !Flags.barClock
            }
        }

        SettingsRow {
            id: dateRow
            surface: root
            name: "Date under clock"
            icon: "calendar"
            LinkToggle {
                s: root.s
                on: Flags.barDate
                onToggled: Flags.barDate = !Flags.barDate
            }
        }

        Item { width: 1; height: 12 * root.s }
    }
}
