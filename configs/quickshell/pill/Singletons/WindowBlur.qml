pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/setDeco.js" as SetDeco

/**
 * General Hyprland effects switch, backed by decoration.lua: blur enabled plus
 * active/inactive window opacity. This is the same switch as Look -> Blur ->
 * Blur + transparency and SUPER+SHIFT+F. Turning it off writes blur=false and
 * opacity=1.00 for both states; turning it back on restores the values saved in
 * Flags. It never edits a terminal-specific stylesheet.
 */
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/hypr/modules/decoration.lua"
    readonly property bool enabled: Flags.windowBlur
    property real activeOpacity: 0.80
    property real inactiveOpacity: 0.50
    property bool loaded: false

    function refresh() {
        reader.reload();
    }

    function parseNumber(text, name, fallback) {
        var value = parseFloat(SetDeco.getField(text, name));
        return isNaN(value) ? fallback : Math.max(0.0, Math.min(1.0, value));
    }

    function applyOpacity() {
        opacityRefresh.command = ["hyprctl", "eval",
            "hl.config({ decoration = { active_opacity = " + activeOpacity.toFixed(2)
            + ", inactive_opacity = " + inactiveOpacity.toFixed(2) + " } })"];
        opacityRefresh.running = true;
    }

    function applyOpacityTo(active, inactive) {
        activeOpacity = active;
        inactiveOpacity = inactive;
        applyOpacity();
    }

    function setEnabled(on) {
        var text = reader.text();
        var targetActive = on ? Flags.fxSavedActive : 1.0;
        var targetInactive = on ? Flags.fxSavedInactive : 1.0;

        if (!on) {
            Flags.fxSavedActive = parseNumber(text, "active_opacity", root.activeOpacity);
            Flags.fxSavedInactive = parseNumber(text, "inactive_opacity", root.inactiveOpacity);
        }

        Flags.windowBlur = on;
        // Global blur is a prerequisite for the independent panel layer rule.
        var result = SetDeco.setBlockField(text, "blur", "enabled", (on || UiBlur.enabled) ? "true" : "false");
        if (!result.ok)
            return;
        result = SetDeco.setField(result.text, "active_opacity", targetActive.toFixed(2));
        if (!result.ok)
            return;
        result = SetDeco.setField(result.text, "inactive_opacity", targetInactive.toFixed(2));
        if (!result.ok)
            return;

        activeOpacity = targetActive;
        inactiveOpacity = targetInactive;
        writer.setText(result.text);
        // Regenerate the panel module so windows gain/lose their no-blur rule.
        UiBlur.sync(on);
        applyOpacity();
    }

    FileView {
        id: reader
        path: root.path
        blockLoading: true
        printErrors: false
        onLoaded: {
            var content = text();
            root.activeOpacity = root.parseNumber(content, "active_opacity", 0.80);
            root.inactiveOpacity = root.parseNumber(content, "inactive_opacity", 0.50);
            root.loaded = true;
            if (!Flags.windowBlur)
                root.applyOpacityTo(1.0, 1.0);
        }
    }

    FileView {
        id: writer
        path: root.path
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: reload
        command: ["hyprctl", "reload"]
        stderr: StdioCollector {}
    }

    Process {
        id: opacityRefresh
        stderr: StdioCollector {}
    }

    Component.onCompleted: refresh()
}
