pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/setDeco.js" as SetDeco

/**
 * General Hyprland window blur, backed by decoration.lua. This is the same
 * switch as Look -> Blur -> Window blur and SUPER+SHIFT+F. It changes the
 * global blur engine, not a terminal-specific stylesheet.
 */
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/hypr/modules/decoration.lua"
    property bool enabled: true
    property bool loaded: false

    function refresh() {
        reader.reload();
    }

    function setEnabled(on) {
        var res = SetDeco.setBlockField(reader.text(), "blur", "enabled", on ? "true" : "false");
        if (!res.ok)
            return;
        enabled = on;
        writer.setText(res.text);
        reload.running = true;
    }

    FileView {
        id: reader
        path: root.path
        blockLoading: true
        printErrors: false
        onLoaded: {
            root.enabled = SetDeco.getBlockField(text(), "blur", "enabled") === "true";
            root.loaded = true;
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

    Component.onCompleted: refresh()
}
