pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/** Pill geometry, material, key notices and configurable system notices. */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    rows: [
        { item: modeRow, kind: "seg", vals: ["always", "auto"], get: function () { return Flags.pillMode; }, set: function (v) { Flags.pillMode = v; } },
        { item: reserveRow, kind: "toggle", get: function () { return Flags.pillReserve; }, set: function (v) { Flags.pillReserve = v; } },
        { item: pillGapRow, kind: "scrub", bump: function (d) { pillGap.bump(d); } },
        { item: appGapRow, kind: "scrub", bump: function (d) { appGap.bump(d); } },
        { item: opacityRow, kind: "scrub", bump: function (d) { opacityScrub.bump(d); } },
        { item: blurRow, kind: "toggle", get: function () { return UiBlur.enabled; }, set: function (v) { UiBlur.setEnabled(v); } },
        { item: noticeRow, kind: "toggle", get: function () { return Flags.keyNoticeEnabled; }, set: function (v) { Flags.keyNoticeEnabled = v; } },
        { item: holdRow, kind: "scrub", bump: function (d) { holdMs.bump(d); } },
        { item: lowBatteryRow, kind: "toggle", get: function () { return Flags.notifyBatteryLow; }, set: function (v) { Flags.notifyBatteryLow = v; } },
        { item: lowPctRow, kind: "scrub", bump: function (d) { lowPct.bump(d); } },
        { item: chargerRow, kind: "toggle", get: function () { return Flags.notifyCharger; }, set: function (v) { Flags.notifyCharger = v; } },
        { item: fullRow, kind: "toggle", get: function () { return Flags.notifyBatteryFull; }, set: function (v) { Flags.notifyBatteryFull = v; } },
        { item: micMuteRow, kind: "toggle", get: function () { return Flags.notifyMicMute; }, set: function (v) { Flags.notifyMicMute = v; } },
        { item: micPlugRow, kind: "toggle", get: function () { return Flags.notifyMicPlug; }, set: function (v) { Flags.notifyMicPlug = v; } },
        { item: peripheralRow, kind: "toggle", get: function () { return Flags.notifyPeripheralLow; }, set: function (v) { Flags.notifyPeripheralLow = v; } }
    ]

    Column {
        id: content
        width: parent.width
        spacing: 0

        SettingsHeader {
            s: root.s
            icon: "layers"
            glyphColor: Theme.vermLit
            title: "PILL"
            showBack: true
        }

        SettingsLabel { s: root.s; text: "Geometry" }

        SettingsRow {
            id: modeRow
            surface: root
            name: "Mode"
            icon: "layers"
            SettingsSeg {
                s: root.s
                options: [{ label: "Always", value: "always" }, { label: "Auto", value: "auto" }]
                value: Flags.pillMode
                onPicked: v => Flags.pillMode = v
            }
        }

        SettingsRow {
            id: reserveRow
            surface: root
            name: "Reserve space"
            icon: "app-window"
            LinkToggle {
                s: root.s
                on: Flags.pillReserve
                onToggled: Flags.pillReserve = !Flags.pillReserve
            }
        }

        SettingsRow {
            id: pillGapRow
            surface: root
            name: "Pill gap"
            icon: "arrow-up"
            ScrubValue {
                id: pillGap
                s: root.s
                value: Flags.topGap
                openValue: 1.0
                from: 0; to: 2; step: 0.1; decimals: 1
                onEdited: v => Flags.topGap = v
            }
        }

        SettingsRow {
            id: appGapRow
            surface: root
            name: "App gap"
            icon: "arrow-up"
            ScrubValue {
                id: appGap
                s: root.s
                value: Flags.appGap
                openValue: 1.0
                from: 0; to: 2; step: 0.1; decimals: 1
                onEdited: v => Flags.appGap = v
            }
        }

        SettingsRow {
            id: opacityRow
            surface: root
            name: "Opacity"
            icon: "sparkles"
            ScrubValue {
                id: opacityScrub
                s: root.s
                value: Flags.pillOpacity
                openValue: 1.0
                from: 0.55; to: 1.0; step: 0.05; decimals: 2
                onEdited: v => Flags.pillOpacity = v
            }
        }

        SettingsRow {
            id: blurRow
            surface: root
            name: "Panel blur"
            sub: "Independent of window blur"
            icon: "sparkles"
            LinkToggle {
                s: root.s
                on: UiBlur.enabled
                onToggled: UiBlur.setEnabled(!UiBlur.enabled)
            }
        }

        SettingsLabel { s: root.s; text: "Key notices" }

        SettingsRow {
            id: noticeRow
            surface: root
            name: "Show notices"
            icon: "keyboard"
            LinkToggle {
                s: root.s
                on: Flags.keyNoticeEnabled
                onToggled: Flags.keyNoticeEnabled = !Flags.keyNoticeEnabled
            }
        }

        SettingsRow {
            id: holdRow
            surface: root
            name: "Hold time"
            icon: "stopwatch"
            ScrubValue {
                id: holdMs
                s: root.s
                value: Flags.keyNoticeMs
                openValue: 500
                from: 200; to: 2000; step: 50; unit: "ms"
                onEdited: v => Flags.keyNoticeMs = v
            }
        }

        SettingsLabel { s: root.s; text: "System notices" }

        SettingsRow {
            id: lowBatteryRow
            surface: root
            name: "Low battery"
            sub: "Notify once per discharge cycle"
            icon: "bolt"
            LinkToggle {
                s: root.s
                on: Flags.notifyBatteryLow
                onToggled: Flags.notifyBatteryLow = !Flags.notifyBatteryLow
            }
        }

        SettingsRow {
            id: lowPctRow
            surface: root
            name: "Low threshold"
            sub: "5–15%"
            icon: "bolt"
            ScrubValue {
                id: lowPct
                s: root.s
                value: Flags.notifyBatteryLowPct
                openValue: 15
                from: 5; to: 15; step: 1; unit: "%"
                onEdited: v => Flags.notifyBatteryLowPct = Math.round(v)
            }
        }

        SettingsRow {
            id: chargerRow
            surface: root
            name: "Charger"
            sub: "Plugged and unplugged"
            icon: "bolt"
            LinkToggle {
                s: root.s
                on: Flags.notifyCharger
                onToggled: Flags.notifyCharger = !Flags.notifyCharger
            }
        }

        SettingsRow {
            id: fullRow
            surface: root
            name: "Battery full"
            icon: "bolt"
            LinkToggle {
                s: root.s
                on: Flags.notifyBatteryFull
                onToggled: Flags.notifyBatteryFull = !Flags.notifyBatteryFull
            }
        }

        SettingsRow {
            id: micMuteRow
            surface: root
            name: "Mic mute"
            sub: "Live and muted"
            icon: "mic"
            LinkToggle {
                s: root.s
                on: Flags.notifyMicMute
                onToggled: Flags.notifyMicMute = !Flags.notifyMicMute
            }
        }

        SettingsRow {
            id: micPlugRow
            surface: root
            name: "Mic plugged"
            sub: "Connect and disconnect"
            icon: "mic"
            LinkToggle {
                s: root.s
                on: Flags.notifyMicPlug
                onToggled: Flags.notifyMicPlug = !Flags.notifyMicPlug
            }
        }

        SettingsRow {
            id: peripheralRow
            surface: root
            name: "Peripheral low"
            sub: "Bluetooth and USB batteries"
            icon: "bluetooth"
            LinkToggle {
                s: root.s
                on: Flags.notifyPeripheralLow
                onToggled: Flags.notifyPeripheralLow = !Flags.notifyPeripheralLow
            }
        }

        Item { width: 1; height: 12 * root.s }
    }
}
