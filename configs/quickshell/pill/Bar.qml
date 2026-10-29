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
    property string selectedComponent: "clock"

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

            BarSection { s: root.s; text: "Components · selected item" }
            BarComponentEditorRow { surface: root; componentId: root.selectedComponent }

            BarSection { s: root.s; text: "Components · tap to select" }
            BarComponentSelectorRow { s: root.s; componentId: "workspaces"; selected: root.selectedComponent === "workspaces"; onPicked: root.selectedComponent = "workspaces" }
            BarComponentSelectorRow { s: root.s; componentId: "clock"; selected: root.selectedComponent === "clock"; onPicked: root.selectedComponent = "clock" }
            BarComponentSelectorRow { s: root.s; componentId: "weather"; selected: root.selectedComponent === "weather"; onPicked: root.selectedComponent = "weather" }
            BarComponentSelectorRow { s: root.s; componentId: "minimized"; selected: root.selectedComponent === "minimized"; onPicked: root.selectedComponent = "minimized" }
            BarComponentSelectorRow { s: root.s; componentId: "tray"; selected: root.selectedComponent === "tray"; onPicked: root.selectedComponent = "tray" }
            BarComponentSelectorRow { s: root.s; componentId: "dnd"; selected: root.selectedComponent === "dnd"; onPicked: root.selectedComponent = "dnd" }
            BarComponentSelectorRow { s: root.s; componentId: "network"; selected: root.selectedComponent === "network"; onPicked: root.selectedComponent = "network" }
            BarComponentSelectorRow { s: root.s; componentId: "inbox"; selected: root.selectedComponent === "inbox"; onPicked: root.selectedComponent = "inbox" }
            BarComponentSelectorRow { s: root.s; componentId: "mixer"; selected: root.selectedComponent === "mixer"; onPicked: root.selectedComponent = "mixer" }
            BarComponentSelectorRow { s: root.s; componentId: "sound"; selected: root.selectedComponent === "sound"; onPicked: root.selectedComponent = "sound" }
            BarComponentSelectorRow { s: root.s; componentId: "thinkpad"; selected: root.selectedComponent === "thinkpad"; onPicked: root.selectedComponent = "thinkpad" }
            BarComponentSelectorRow { s: root.s; componentId: "sysmon"; selected: root.selectedComponent === "sysmon"; onPicked: root.selectedComponent = "sysmon" }
            BarComponentSelectorRow { s: root.s; componentId: "updates"; selected: root.selectedComponent === "updates"; onPicked: root.selectedComponent = "updates" }
            BarComponentSelectorRow { s: root.s; componentId: "recorder"; selected: root.selectedComponent === "recorder"; onPicked: root.selectedComponent = "recorder" }
            BarComponentSelectorRow { s: root.s; componentId: "settings"; selected: root.selectedComponent === "settings"; onPicked: root.selectedComponent = "settings" }
            BarComponentSelectorRow { s: root.s; componentId: "power"; selected: root.selectedComponent === "power"; onPicked: root.selectedComponent = "power" }

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
