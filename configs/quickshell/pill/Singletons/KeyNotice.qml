pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Brief, focused-monitor pill notice for expected keybind state changes.
 *
 * The keyboard layout is watched from Hyprland itself, so Super+Space (and any
 * other layout switch) needs no wrapper script. Other actions can publish a
 * notice through `show()` or `qs -c pill ipc call pill notice ...`.
 */
Singleton {
    id: root

    signal notice(string icon, string label, string value)

    property bool enabled: Flags.keyNoticeEnabled
    property string lastKeymap: ""
    property bool armed: false

    function shortName(keymap) {
        if (keymap.indexOf("English (US, intl") >= 0)
            return "US INTL";
        if (keymap.indexOf("English (US)") >= 0)
            return "US";
        if (keymap.indexOf("English (UK)") >= 0)
            return "UK";
        if (keymap.indexOf("German") >= 0) return "DE";
        if (keymap.indexOf("French") >= 0) return "FR";
        if (keymap.indexOf("Spanish") >= 0) return "ES";
        if (keymap.indexOf("Italian") >= 0) return "IT";
        if (keymap.indexOf("Portuguese (Brazil") >= 0) return "BR";
        if (keymap.indexOf("Portuguese") >= 0) return "PT";
        if (keymap.indexOf("Turkish") >= 0) return "TR";
        if (keymap.indexOf("Russian") >= 0) return "RU";
        if (keymap.indexOf("Japanese") >= 0) return "JP";
        if (keymap.indexOf("Korean") >= 0) return "KR";
        return keymap.replace(/\s+with\s+dead\s+keys/i, "").split(",")[0].slice(0, 22);
    }

    function show(icon, label, value) {
        if (!root.enabled)
            return;
        root.notice(icon, label, value);
    }

    function read(text) {
        try {
            var data = JSON.parse(text);
            var keyboards = data.keyboards || [];
            var keymap = "";
            for (var i = 0; i < keyboards.length; i++) {
                if (keyboards[i].active_keymap && keyboards[i].active_keymap.length > 0) {
                    keymap = keyboards[i].active_keymap;
                    break;
                }
            }
            if (keymap.length === 0)
                return;
            if (root.lastKeymap.length === 0 || !root.armed) {
                root.lastKeymap = keymap;
                return;
            }
            if (keymap === root.lastKeymap)
                return;
            root.lastKeymap = keymap;
            root.show("keyboard", "Language", root.shortName(keymap));
        } catch (e) {
            // A transient hyprctl failure must not break the watcher.
        }
    }

    Process {
        id: devices
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.read(this.text)
        }
    }

    Timer {
        interval: 700
        running: Flags.keyNoticeEnabled
        repeat: true
        onTriggered: if (!devices.running) devices.running = true
    }

    Timer {
        interval: 1400
        running: true
        onTriggered: root.armed = true
    }

    Component.onCompleted: {
        if (!devices.running)
            devices.running = true;
    }
}
