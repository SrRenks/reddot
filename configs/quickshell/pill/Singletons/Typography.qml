pragma Singleton
import QtQuick
import Quickshell

/**
 * One type scale for the whole pill. Sizes are expressed in logical pixels at
 * scale 1; every surface multiplies by its `s`, which already includes the
 * monitor scale and the user's UI scale. Use `Typography.size(role, s)` instead
 * of adding another literal `font.pixelSize`.
 *
 * Roles are deliberately few: micro/caption for labels, body/bodyLarge for
 * copy and values, subtitle/title for headers, display/hero for numbers.
 */
Singleton {
    readonly property real micro: 8.5
    readonly property real caption: 9.5
    readonly property real body: 11
    readonly property real bodyLarge: 12.5
    readonly property real subtitle: 14
    readonly property real title: 16
    readonly property real display: 22
    readonly property real hero: 30

    function size(role, scale) {
        var base = body;
        if (role === "micro") base = micro;
        else if (role === "caption") base = caption;
        else if (role === "bodyLarge") base = bodyLarge;
        else if (role === "subtitle") base = subtitle;
        else if (role === "title") base = title;
        else if (role === "display") base = display;
        else if (role === "hero") base = hero;
        return base * (scale > 0 ? scale : 1);
    }
}
