pragma Singleton
import QtQuick
import Quickshell

/**
 * Lock palette, same split as the pill's Theme: the fixed hex is the identity
 * and the default, and with the dynamic-palette flag on the accent and text
 * family follow the wallpaper through Dyn. Each token is a single ternary, so
 * static mode renders byte-identical to the old fixed theme.
 */
Singleton {
    readonly property bool dyn: Flags.paletteMode !== "static"

    readonly property color verm:   dyn ? Qt.darker(Dyn.primary, 1.18) : "#b00018"
    readonly property color cream:  dyn ? Dyn.cream : "#f2f2f2"
    readonly property color bright: dyn ? Dyn.bright : "#ffffff"
    readonly property color dim:    dyn ? Dyn.dim : "#8a8a8a"
    readonly property string font:  "Inter"

    readonly property color fieldBg: dyn ? Qt.alpha(bright, 0.10) : Qt.rgba(1, 1, 1, 0.10)
    readonly property color fieldBorder: dyn ? Qt.alpha(cream, 0.30) : Qt.rgba(1, 1, 1, 0.28)
    readonly property color trackBg: dyn ? Qt.alpha(cream, 0.16) : Qt.rgba(1, 1, 1, 0.16)
    readonly property color error:  dyn ? Dyn.primary : "#e60012"
}
