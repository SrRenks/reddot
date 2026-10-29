pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "barLayout.js" as BarLayoutMath

/**
 * Persisted instance layout for the bar component catalog.
 *
 * The first run migrates the legacy Flags visibility/order into bar.json. After
 * that the JSON file is authoritative; settings mutate this singleton and write
 * the file atomically. Rendering reads instancesFor()/enabled() so a future host
 * can place the same component in more than one slot without touching the shell.
 */
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/reddot"

    property var layout: ({ version: BarLayoutMath.VERSION, items: [] })
    property bool loaded: false

    readonly property var items: layout.items
    readonly property var statusOrder: BarLayoutMath.statusIds(layout)

    function load() {
        if (root.loaded)
            return;
        var raw = null;
        var text = "";
        try {
            text = file.text();
            if (text && text.trim().length > 0)
                raw = JSON.parse(text);
        } catch (error) {
            raw = null;
        }
        if (raw === null) {
            root.seedLegacy();
            return;
        }
        root.layout = BarLayoutMath.ensureBar(
            BarLayoutMath.normalize(raw, BarCatalog.definitions));
        root.loaded = true;
        root.persist();
    }

    /** Migrate once from the Flags booleans when no bar.json exists yet. */
    function seedLegacy() {
        root.layout = BarLayoutMath.migrateFlags({
            barWorkspaces: Flags.barWorkspaces,
            barClock: Flags.barClock,
            barWeather: Flags.barWeather,
            barMinimized: Flags.barMinimized,
            barTray: Flags.barTray,
            barDnd: Flags.barDnd,
            barNetwork: Flags.barNetwork,
            barInbox: Flags.barInbox,
            barMixer: Flags.barMixer,
            barSound: Flags.barSound,
            barThinkpad: Flags.barThinkpad,
            barSysmon: Flags.barSysmon,
            barUpdates: Flags.barUpdates,
            barRecorder: Flags.barRecorder,
            barSettings: Flags.barSettings,
            barPower: Flags.barPower,
            barStatusOrder: Flags.barStatusOrder
        }, BarCatalog.definitions);
        root.loaded = true;
        root.persist();
    }

    function persist() {
        writer.setText(JSON.stringify(root.layout));
    }

    function exportJson() {
        return JSON.stringify(root.layout);
    }

    /** Import a full layout after schema validation; returns an error string or "". */
    function importJson(text) {
        var parsed = null;
        try {
            parsed = JSON.parse(text);
        } catch (error) {
            return "invalid JSON";
        }
        var check = BarLayoutMath.validate(parsed, BarCatalog.definitions);
        if (!check.ok)
            return check.errors.join("; ");
        root.layout = BarLayoutMath.ensureBar(check.layout);
        root.persist();
        return "";
    }

    function enabled(id) {
        return BarLayoutMath.enabled(root.layout, id);
    }

    function mode(id) {
        return BarLayoutMath.mode(root.layout, id);
    }

    function hostOf(id) {
        return BarLayoutMath.hostOf(root.layout, id);
    }

    function findHost(id) {
        var host = root.hostOf(id);
        return host.length > 0 ? host : "unplaced";
    }

    function setEnabled(id, value) {
        root.layout = BarLayoutMath.setEnabled(root.layout, id, value);
        root.persist();
    }

    function setMode(id, value) {
        root.layout = BarLayoutMath.setMode(root.layout, id, value);
        root.persist();
    }

    function setHost(id, host) {
        root.layout = BarLayoutMath.setHost(root.layout, id, host);
        root.persist();
    }

    function instancesFor(host, enabledOnly) {
        return BarLayoutMath.instancesFor(root.layout, host, enabledOnly !== false);
    }

    function instancesForMode(host, mode) {
        return BarLayoutMath.instancesForMode(root.layout, host, mode);
    }

    function setStatusOrder(ids) {
        root.layout = BarLayoutMath.setStatusOrder(root.layout, ids);
        root.persist();
    }

    function moveStatus(id, target) {
        root.layout = BarLayoutMath.moveItem(root.layout, "bar.right", id, target);
        root.persist();
    }

    function reverseStatus() {
        root.layout = BarLayoutMath.reverseHost(root.layout, "bar.right");
        root.persist();
    }

    Component.onCompleted: root.load()

    FileView {
        id: file
        path: root.stateDir + "/bar.json"
        blockLoading: true
        printErrors: false

        onLoadFailed: function (error) {
            if (error === FileViewError.FileNotFound && !root.loaded)
                root.seedLegacy();
        }
    }

    FileView {
        id: writer
        path: root.stateDir + "/bar.json"
        atomicWrites: true
        printErrors: false
    }
}
