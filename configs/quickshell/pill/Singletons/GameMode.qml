pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Game mode: one flag that strips Hyprland's eye-candy and quiets the desktop for
 * gaming or deep focus. Entering snapshots the focus flags, forces do-not-disturb
 * and keep-awake on, pauses the visualizer, and runs the visual strip; leaving
 * restores each to what it was before. The strip itself lives in gamemode.sh so
 * the original decoration values survive a pill restart. `Flags.gameMode` is the
 * single source of truth, flipped by the mixer chip, the keybind, or IPC.
 */
Singleton {
    id: root

    readonly property bool active: Flags.gameMode
    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/gamemode.sh"
    readonly property string cleanupScript: Quickshell.env("HOME") + "/.config/hypr/scripts/gamemode-cleanup.sh"
    readonly property var keepClasses: {
        var out = [];
        var parts = String(Flags.gameModeKeepClasses || "").split(",");
        for (var i = 0; i < parts.length; i++) {
            var v = parts[i].trim();
            if (v.length > 0 && out.indexOf(v) < 0)
                out.push(v);
        }
        return out;
    }
    property string targetClass: Flags.gameModeTargetClass
    property string targetTitle: ""
    property var windows: []
    property string cleanupOutput: ""
    property bool busy: false
    property bool refreshing: false
    property string pending: ""

    onActiveChanged: active ? root.enter() : root.leave()
    Component.onCompleted: targetClass = Flags.gameModeTargetClass

    function enter() {
        Flags.gamePrevDnd = Flags.dnd;
        Flags.gamePrevViz = Flags.musicViz;
        Flags.gamePrevAwake = Flags.keepAwake;
        Flags.dnd = true;
        Flags.musicViz = false;
        Flags.keepAwake = true;
        root.run("on");
    }

    function leave() {
        root.run("off");
        Flags.dnd = Flags.gamePrevDnd;
        Flags.musicViz = Flags.gamePrevViz;
        Flags.keepAwake = Flags.gamePrevAwake;
    }

    function refreshWindows() {
        if (clientsProc.running || root.refreshing)
            return;
        root.refreshing = true;
        clientsProc.running = true;
    }

    function acceptClients(text) {
        var data = [];
        try { data = JSON.parse(text); } catch (e) { return; }
        var out = [];
        var found = false;
        for (var i = 0; i < data.length; i++) {
            var w = data[i];
            if (!w || !w.pid || !w.class)
                continue;
            var app = {
                id: String(w.pid) + "|" + String(w.class),
                pid: w.pid,
                klass: String(w.class),
                title: String(w.title || w.class),
                fullscreen: w.fullscreen === true
            };
            out.push(app);
            if (root.targetClass.length > 0 && app.klass === root.targetClass)
                found = true;
        }
        root.windows = out;
        if (root.targetClass.length > 0) {
            for (var j = 0; j < out.length; j++)
                if (out[j].klass === root.targetClass) {
                    root.targetTitle = out[j].title;
                    break;
                }
        }
        if (root.active && root.targetClass.length > 0 && !found)
            Flags.gameMode = false;
        root.refreshing = false;
    }

    function chooseWindow(app) {
        if (!app)
            return;
        root.targetClass = app.klass;
        root.targetTitle = app.title;
        Flags.gameModeTargetClass = app.klass;
    }

    function isTarget(app) {
        return app && root.targetClass === app.klass;
    }

    function isKept(app) {
        return isTarget(app) || root.keepClasses.indexOf(app.klass) >= 0;
    }

    function setKept(app, on) {
        if (!app || isTarget(app))
            return;
        var list = root.keepClasses.slice();
        var idx = list.indexOf(app.klass);
        if (on && idx < 0)
            list.push(app.klass);
        else if (!on && idx >= 0)
            list.splice(idx, 1);
        Flags.gameModeKeepClasses = list.join(",");
    }

    function startGame() {
        if (root.active || root.targetClass.length === 0)
            return;
        Flags.gameModeTargetClass = root.targetClass;
        root.cleanupOutput = "";
        if (Flags.gameModeKillOthers) {
            root.busy = true;
            cleanupProc.command = ["bash", root.cleanupScript, "terminate",
                root.targetClass, Flags.gameModeKeepClasses];
            cleanupProc.running = true;
        }
        Flags.gameMode = true;
    }

    function stopGame() {
        Flags.gameMode = false;
    }

    function run(arg) {
        if (proc.running) {
            root.pending = arg;
            return;
        }
        proc.command = ["bash", root.script, arg];
        proc.running = true;
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.acceptClients(this.text)
        }
    }

    Process {
        id: cleanupProc
        stdout: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0)
                root.cleanupOutput = this.text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0)
                root.cleanupOutput = this.text.trim()
        }
        onExited: root.busy = false
    }

    Timer {
        interval: 2500
        repeat: true
        running: root.active
        onTriggered: root.refreshWindows()
    }

    Process {
        id: proc
        onExited: {
            if (root.pending.length === 0)
                return;
            var a = root.pending;
            root.pending = "";
            proc.command = ["bash", root.script, a];
            proc.running = true;
        }
    }
}
