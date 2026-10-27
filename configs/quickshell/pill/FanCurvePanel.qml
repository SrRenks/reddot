pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "Singletons"

/** Thinkfan curve editor, embedded in System next to the fan gauges. */
Column {
    id: panel

    property real s: 1
    property var surface: null

    width: parent ? parent.width : 0
    spacing: 0

    readonly property bool ready: ThinkPad.present && ThinkPad.curve.length === 8
    property bool busy: false
    property bool dirty: false
    property var draft: []
    property string notice: ""

    function sync(force) {
        if (!force && dirty)
            return;
        var next = [];
        for (var i = 0; i < ThinkPad.curve.length; i++)
            next.push({
                level: ThinkPad.curve[i].level,
                low: ThinkPad.curve[i].low,
                high: ThinkPad.curve[i].high
            });
        draft = next;
    }

    function setCurve(index, edge, value) {
        if (index < 0 || index >= draft.length)
            return;
        var next = draft.slice();
        var item = {
            level: next[index].level,
            low: next[index].low,
            high: next[index].high
        };
        item[edge] = value;
        next[index] = item;
        draft = next;
        dirty = true;
    }

    function applyCurve() {
        var parts = [];
        for (var i = 0; i < draft.length; i++)
            parts.push(draft[i].level + ":" + draft[i].low + ":" + draft[i].high);
        if (actionProc.running)
            return;
        busy = true;
        notice = "authentication required…";
        actionProc.command = ["/usr/bin/pkexec", ThinkPad.helper, "curve", "set", parts.join(";")];
        actionProc.running = true;
    }

    onReadyChanged: if (ready && draft.length === 0) sync(true)
    Component.onCompleted: sync(true)

    Connections {
        target: ThinkPad
        function onCurveChanged() {
            if (!panel.dirty)
                panel.sync(true);
        }
    }

    ThinkPadGroup {
        s: panel.s
        title: "Fan curve"
        open: false
        visible: panel.ready

        onOpenChanged: if (open) {
            ThinkPad.refresh();
            if (!panel.dirty)
                panel.sync(true);
        }

        ThinkPadCurve {
            s: panel.s
            surface: panel.surface
            rows: panel.draft
            busy: panel.busy
            dirty: panel.dirty
            onEdited: (index, edge, value) => panel.setCurve(index, edge, value)
            onApplied: panel.applyCurve()
            onReset: {
                panel.dirty = false;
                panel.sync(true);
            }
        }

        Item {
            width: parent.width
            height: panel.notice.length > 0 ? note.implicitHeight + 8 * panel.s : 0

            Text {
                id: note
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 2 * panel.s
                text: panel.notice
                color: panel.notice === "saved" ? Theme.faint : Theme.flameCore
                font.family: Theme.font
                font.pixelSize: 9 * panel.s
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }
    }

    Process {
        id: actionProc
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0)
                panel.notice = this.text.trim()
        }
        onExited: (code) => {
            panel.busy = false;
            if (code === 0) {
                panel.notice = "saved";
                panel.dirty = false;
                ThinkPad.refresh();
                panel.sync(true);
            } else if (panel.notice.length === 0) {
                panel.notice = "authentication cancelled or helper failed (" + code + ")";
            }
        }
    }
}
