pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * BAR sub-surface. Layout controls plus two tap/drag lists: the status cluster
 * is drag-reordered with a grip; fixed zones toggle by tapping their label. No
 * switches or arrow buttons are shown.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    rows: [
        { item: alignRow, kind: "seg", vals: ["left", "center", "right"], get: function () { return Flags.barAlign; }, set: function (v) { Flags.barAlign = v; } },
        { item: orderRow, kind: "seg", vals: ["standard", "mirrored"], get: function () { return Flags.barOrder; }, set: function (v) { Flags.barOrder = v; } },
        { item: reverseRow, kind: "toggle", get: function () { return Flags.barStatusReverse; }, set: function (v) { Flags.barStatusReverse = v; } }
    ]

    Column {
        id: content
        width: parent.width
        spacing: 0

            SettingsHeader {
                s: root.s
                icon: "layers"
                glyphColor: Theme.vermLit
                title: "BAR"
                showBack: true
            }

            BarSection { s: root.s; text: "Layout" }

            SettingsRow {
                id: alignRow
                surface: root
                name: "Alignment"
                icon: "scaling"
                sub: "Where the bar sits horizontally"

                SettingsSeg {
                    s: root.s
                    options: [{ label: "L", value: "left" }, { label: "C", value: "center" }, { label: "R", value: "right" }]
                    value: Flags.barAlign
                    onPicked: (v) => Flags.barAlign = v
                }
            }

            SettingsRow {
                id: orderRow
                surface: root
                name: "Order"
                icon: "undo"
                sub: "Mirror the three bar zones"

                SettingsSeg {
                    s: root.s
                    options: [{ label: "Standard", value: "standard" }, { label: "Mirrored", value: "mirrored" }]
                    value: Flags.barOrder
                    onPicked: (v) => Flags.barOrder = v
                }
            }

            SettingsRow {
                id: reverseRow
                surface: root
                name: "Reverse status icons"
                icon: "arrow-up"
                sub: "Only the right-side status cluster"

                LinkToggle {
                    s: root.s
                    on: Flags.barStatusReverse
                    onToggled: Flags.barStatusReverse = !Flags.barStatusReverse
                }
            }

            BarSection { s: root.s; text: "Zones · tap to show/hide" }
            BarZoneList { s: root.s; width: parent.width }

            BarSection { s: root.s; text: "Status · drag grip · tap to show/hide" }
            StatusOrderList { s: root.s; width: root.width }

            BarSection { s: root.s; text: "Components · host and mode" }

            BarComponentEditorRow { surface: root; componentId: "workspaces" }
            BarComponentEditorRow { surface: root; componentId: "clock" }
            BarComponentEditorRow { surface: root; componentId: "weather" }
            BarComponentEditorRow { surface: root; componentId: "minimized" }
            BarComponentEditorRow { surface: root; componentId: "tray" }
            BarComponentEditorRow { surface: root; componentId: "dnd" }
            BarComponentEditorRow { surface: root; componentId: "network" }
            BarComponentEditorRow { surface: root; componentId: "inbox" }
            BarComponentEditorRow { surface: root; componentId: "mixer" }
            BarComponentEditorRow { surface: root; componentId: "sound" }
            BarComponentEditorRow { surface: root; componentId: "thinkpad" }
            BarComponentEditorRow { surface: root; componentId: "sysmon" }
            BarComponentEditorRow { surface: root; componentId: "updates" }
            BarComponentEditorRow { surface: root; componentId: "recorder" }
            BarComponentEditorRow { surface: root; componentId: "settings" }
            BarComponentEditorRow { surface: root; componentId: "power" }

            SettingsRow {
                surface: root
                name: "Bar"
                icon: "layers"
                sub: "Container · settings.catalog"
            }

            BarSection { s: root.s; text: "Bar widget · settings.catalog" }
            BarWidget { s: root.s }

            Text {
                width: parent.width
                topPadding: 8 * root.s
                bottomPadding: 12 * root.s
                text: "The grip reorders the item; tapping its label hides or shows it. Mirrored order moves the status cluster before the clock."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: Typography.size("micro", root.s)
                wrapMode: Text.WordWrap
            }
        }
}
