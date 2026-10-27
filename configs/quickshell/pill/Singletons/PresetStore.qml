pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * User-named power presets. One JSON file, editable by hand, watched for
 * external changes. Every entry is a complete TLP snapshot: profile plus charge
 * window. Nothing here is treated as active until a live TLP status read
 * matches it.
 */
Singleton {
    id: root

    readonly property var defaults: [
        { name: "Desktop", profile: "performance", start: 40, stop: 80 },
        { name: "Laptop", profile: "balanced", start: 95, stop: 100 }
    ]

    property alias presets: adapter.presets

    function setPresets(list) {
        adapter.presets = list;
    }

    function add(preset) {
        var next = presets.slice();
        next.push(preset);
        setPresets(next);
    }

    function update(index, preset) {
        var next = presets.slice();
        next[index] = preset;
        setPresets(next);
    }

    function remove(index) {
        var next = presets.slice();
        next.splice(index, 1);
        setPresets(next);
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
            + "/reddot/presets.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: function (error) {
            if (error === FileViewError.FileNotFound) {
                adapter.presets = root.defaults;
                writeAdapter();
            }
        }

        JsonAdapter {
            id: adapter
            property int version: 1
            property var presets: []
        }
    }
}
