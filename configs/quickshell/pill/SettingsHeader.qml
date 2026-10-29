import QtQuick
import "Singletons"

/**
 * Settings surface header: the surface kanji (gated by Flags.showGlyphs) and its
 * uppercase title on the left, with a cog at the index or a back chevron on a
 * sub-surface at the right. The header strip is the back target, but the click is
 * handled at the pill level (a press anywhere on the top strip steps the surface
 * back), so this is a pure visual. Other surfaces reuse it with `showIcon` off,
 * their own right-side controls as children and `titleContent` items after the
 * title.
 */
Item {
    id: head

    property real s: 1
    property string glyph: ""
    property string title: ""
    property bool showBack: false
    property bool showIcon: true
    property bool forceGlyph: false
    property string icon: ""
    property bool iconAccent: false
    property real iconSize: 18
    property color glyphColor: Theme.cream
    property color iconAccentColor: Theme.verm
    property alias titleContent: titleRow.data

    width: parent ? parent.width : 0
    height: 22 * head.s

    Row {
        id: titleRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * head.s

        Item {
            anchors.verticalCenter: parent.verticalCenter
            visible: head.icon.length > 0
            width: visible ? head.iconSize * head.s : 0
            height: head.iconSize * head.s

            GlyphIcon {
                anchors.fill: parent
                name: head.icon
                color: head.glyphColor
                stroke: 1.9
            }

            /** Small vermilion TrackPoint/lid accent, readable on the cream mark. */
            Rectangle {
                visible: head.iconAccent
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 2 * head.s
                width: 6 * head.s
                height: 6 * head.s
                radius: width / 2
                color: head.iconAccentColor
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: head.icon.length === 0 && (Flags.showGlyphs || head.forceGlyph)
                && head.glyph.length > 0
            text: head.glyph
            color: head.glyphColor
            font.family: Theme.fontJp
            font.weight: Font.Medium
            font.pixelSize: Typography.size("title", head.s)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: head.title
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: Typography.size("subtitle", head.s)
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.6 * head.s
        }
    }

    GlyphIcon {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        /** The shared in-pill strip now owns back; suppress the old header chevron. */
        visible: head.showIcon && !head.showBack
        width: 16 * head.s
        height: 16 * head.s
        name: head.showBack ? "chevron-left" : "cog"
        color: head.showBack ? Theme.vermLit : Theme.iconDim
        stroke: head.showBack ? 2.2 : 1.7
    }
}
