pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Settings index, grouped by ownership: visual identity, shell, window manager,
 * and system controls. Each row carries a short description and opens one hub or
 * a focused subpage.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    rows: [
        { item: appearanceRow, kind: "nav", surface: "appearance" },
        { item: shellRow, kind: "nav", surface: "shell" },
        { item: windowsRow, kind: "nav", surface: "windows" },
        { item: displayRow, kind: "nav", surface: "display" },
        { item: inputRow, kind: "nav", surface: "input" },
        { item: securityRow, kind: "nav", surface: "idlelock" },
        { item: shortcutsRow, kind: "nav", surface: "shortcuts" },
        { item: powerRow, kind: "nav", surface: "powerhub" },
        { item: systemRow, kind: "nav", surface: "sysmon" },
        { item: maintenanceRow, kind: "nav", surface: "maintenance" }
    ]

    component Arrow: GlyphIcon {
        width: 16 * root.s
        height: 16 * root.s
        name: "chevron-right"
        color: Theme.iconDim
        stroke: 2.2
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "設"
            title: "SETTINGS"
        }

        SettingsLabel { s: root.s; text: "Desktop" }

        SettingsRow {
            id: appearanceRow
            surface: root
            captionOnFocus: true
            icon: "sparkles"
            name: "Appearance"
            sub: "Theme, palette, typography, comfort"
            Arrow {}
        }

        SettingsRow {
            id: shellRow
            surface: root
            captionOnFocus: true
            icon: "layers"
            name: "Shell"
            sub: "Bar, clock, pill, notices"
            Arrow {}
        }

        SettingsRow {
            id: windowsRow
            surface: root
            captionOnFocus: true
            icon: "app-window"
            name: "Windows"
            sub: "Layout, gaps, effects, motion"
            Arrow {}
        }

        SettingsRow {
            id: displayRow
            surface: root
            captionOnFocus: true
            icon: "monitor"
            name: "Display"
            sub: "Resolution, refresh, scale"
            Arrow {}
        }

        SettingsLabel { s: root.s; text: "Controls" }

        SettingsRow {
            id: inputRow
            surface: root
            captionOnFocus: true
            icon: "keyboard"
            name: "Input"
            sub: "Pointer, keyboard, touchpad, cursor"
            Arrow {}
        }

        SettingsRow {
            id: securityRow
            surface: root
            captionOnFocus: true
            icon: "lock"
            name: "Security"
            sub: "Fingerprint and idle lock"
            Arrow {}
        }

        SettingsRow {
            id: shortcutsRow
            surface: root
            captionOnFocus: true
            icon: "return"
            name: "Shortcuts"
            sub: "Keybinds and special workspaces"
            Arrow {}
        }

        SettingsLabel { s: root.s; text: "System" }

        SettingsRow {
            id: powerRow
            surface: root
            captionOnFocus: true
            icon: "bolt"
            name: "Power"
            sub: "Profile, battery care, session"
            Arrow {}
        }

        SettingsRow {
            id: systemRow
            surface: root
            captionOnFocus: true
            icon: "waves"
            name: "System"
            sub: "Sensors, cooling, compute"
            Arrow {}
        }

        SettingsRow {
            id: maintenanceRow
            surface: root
            captionOnFocus: true
            icon: "download"
            name: "Maintenance"
            sub: "Startup commands and updates"
            Arrow {}
        }
    }
}
