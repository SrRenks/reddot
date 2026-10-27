pragma Singleton
import QtQuick
import Quickshell

/**
 * Pill palette. Two sources: the curated washi/flame hex below is the identity
 * and the default, used whenever the dynamic-palette flag is off. With the flag
 * on, the surfaces and the whole accent ramp follow the wallpaper through the
 * matugen-fed `Dyn` singleton, while the text family, light veils and shadow
 * stay locked here so copy keeps its contrast on any generated background. Each
 * token is a single ternary, so static mode renders byte-identical to the fixed
 * theme and only the colours that should breathe with the wallpaper do.
 */
Singleton {
    readonly property bool dyn: Flags.paletteMode !== "static"

    /**
     * Bright warm pop shared by the flame glow, charging glyphs, the recording
     * countdown, the unread inbox dot, the calendar's today cell and the held
     * power tile. The dynamic branch uses the wallpaper accent (Dyn.primary):
     * matugen's on-primary-container does not populate here and collapses the
     * token to black, while the accent always loads and contrasts the pill
     * surface. Static mode keeps the fixed ThinkPad-red hex.
     */
    readonly property color onGlow: dyn ? Dyn.primary : "#ff3344"

    readonly property color verm:     dyn ? Qt.darker(Dyn.primary, 1.18) : "#b00018"
    readonly property color vermLit:  dyn ? Dyn.primary : "#e60012"
    readonly property color vermDeep: dyn ? Dyn.primaryContainer : "#7a0010"
    readonly property color cream:    dyn ? Dyn.cream : "#f2f2f2"
    readonly property color bright:   dyn ? Dyn.bright : "#ffffff"
    readonly property color dim:      dyn ? Dyn.dim : "#8a8a8a"
    readonly property color cardTop:  dyn ? Dyn.surfaceContainerHigh : "#181818"
    readonly property color cardBot:  dyn ? Dyn.surfaceContainerLow : "#0d0d0d"
    readonly property color border:   dyn ? Dyn.outlineVariant : "#2a2a2a"
    readonly property color shadow:     Qt.rgba(0, 0, 0, 0.55)
    readonly property color tileBg:   dyn ? Dyn.surface : "#0b0b0b"
    readonly property color subtle:   dyn ? Dyn.subtle : "#b8b8b8"
    readonly property color faint:    dyn ? Dyn.faint : "#707070"
    readonly property color iconDim:  dyn ? Dyn.iconDim : "#d0d0d0"
    readonly property color hair:     Qt.alpha(cream, 0.13)
    readonly property color hairSoft: Qt.alpha(cream, 0.08)
    readonly property color sheen:    Qt.alpha(cream, 0.07)
    readonly property color vermDim:   dyn ? Qt.darker(Dyn.primary, 1.5) : "#76000e"
    readonly property color vermDimDeep: dyn ? Qt.darker(Dyn.primary, 2.2) : "#3a0006"
    readonly property color vermBurn:  dyn ? Qt.darker(Dyn.primaryContainer, 1.1) : "#5f000c"
    readonly property color tickRest:  dyn ? Dyn.tickRest : "#c8c8c8"
    readonly property color threadBg:  Qt.alpha(cream, 0.13)
    readonly property color flameCore: dyn ? Qt.lighter(onGlow, 1.03) : "#ff6670"
    readonly property color flameGlow: dyn ? onGlow : "#ff3344"

    /**
     * Flame canvas ramp: literal hex strings (color type won't work), fed
     * directly to Canvas addColorStop/strokeStyle. A color property serializes
     * to #aarrggbb and corrupts the gradient render, so the dynamic branch passes
     * matugen's raw hex strings through untouched rather than any Qt.darker math.
     */
    readonly property string flameInk:   dyn ? Dyn.primary : "#e60012"
    readonly property string flameEmber: dyn ? Dyn.primaryContainer : "#7a0010"
    readonly property string flameBurn:  dyn ? Dyn.primaryContainer : "#5f000c"
    readonly property string flameTip:   dyn ? Dyn.onPrimaryContainer : "#ff8090"
    readonly property color todayWarm: dyn ? onGlow : "#ff8090"
    readonly property color ghost:     dyn ? Dyn.surfaceContainerHighest : "#303030"
    readonly property color frameBg:      Qt.alpha(cream, 0.055)
    readonly property color frameBorder:  Qt.alpha(cream, 0.10)
    readonly property color creamMenu:     Qt.alpha(cream, 0.82)
    readonly property real shadowOpacity: 0.5
    /**
     * Snapshot of the system families, not a binding: Qt.fontFamilies() is not
     * notifiable, so a font dropped onto the pill re-registers through
     * refreshFonts() once its FontLoader is ready.
     */
    property var fontFamilies: Qt.fontFamilies()
    function refreshFonts() { fontFamilies = Qt.fontFamilies(); }
    readonly property string font: (Flags.uiFont.length > 0 && fontFamilies.indexOf(Flags.uiFont) >= 0) ? Flags.uiFont : "Inter"
    readonly property string fontJp: "Zen Kaku Gothic New"

    /**
     * MPRIS trackArtists arrives as a JS array from some players and as a
     * plain string from others (Spotify); calling join on the string throws
     * and kills the whole binding. Handles both, falls back to trackArtist.
     */
    function joinArtists(artists, single) {
        if (artists && typeof artists.join === "function" && artists.length > 0)
            return artists.join(", ");
        if (artists && String(artists).length > 0)
            return String(artists);
        return single ? String(single) : "";
    }
}
