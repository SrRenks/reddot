pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Generic LED editor: choose any LED exposed under /sys/class/leds, then edit its
 * brightness, kernel trigger and timer delays. Everything is capability driven:
 * a missing trigger list or timer file simply removes that control.
 *
 * Useful LEDs on a ThinkPad:
 *  - tpacpi::lid_logo_dot  lid logo (0..255)
 *  - tpacpi::kbd_backlight keyboard backlight (0..2)
 *  - input3::capslock / numlock / scrolllock  keyboard lock indicators
 *  - platform::micmute / mute  mute LEDs
 *  - tpacpi::power / standby / thinkvantage  firmware indicators
 */
Column {
    id: editor

    property real s: 1
    property var surface: null
    property string ledName: ""
    property string notice: ""

    readonly property var names: {
        var preferred = ["tpacpi::lid_logo_dot", "tpacpi::kbd_backlight",
                         "platform::micmute", "platform::mute",
                         "input3::capslock", "input3::numlock", "input3::scrolllock"];
        var out = [];
        for (var p = 0; p < preferred.length; p++)
            for (var i = 0; i < ThinkPad.ledsAll.length; i++)
                if (ThinkPad.ledsAll[i].name === preferred[p])
                    out.push(ThinkPad.ledsAll[i].name);
        for (var j = 0; j < ThinkPad.ledsAll.length; j++)
            if (out.indexOf(ThinkPad.ledsAll[j].name) < 0)
                out.push(ThinkPad.ledsAll[j].name);
        return out;
    }
    readonly property var selected: {
        for (var i = 0; i < ThinkPad.ledsAll.length; i++)
            if (ThinkPad.ledsAll[i].name === editor.ledName)
                return ThinkPad.ledsAll[i];
        return null;
    }
    readonly property var meta: ThinkPad.ledInfo(editor.ledName)
    readonly property var triggers: {
        var out = [];
        // Put the effect triggers first: they are the reason to open this editor
        // and would otherwise sit after the kernel's long hwmon/NIC list.
        for (var j = 0; j < ThinkPad.extraTriggers.length; j++)
            out.push(ThinkPad.extraTriggers[j]);
        var base = meta.triggers || [];
        for (var i = 0; i < base.length; i++)
            if (out.indexOf(base[i]) < 0)
                out.push(base[i]);
        return out;
    }
    readonly property bool timerAvailable: triggers.indexOf("timer") >= 0
    readonly property int max: selected ? (selected.max || 1) : 1
    readonly property int live: ThinkPad.ledValue(editor.ledName, selected ? selected.value : 0)
    readonly property string currentTrigger: meta.trigger || "none"

    width: parent ? parent.width : 0
    spacing: 5 * editor.s

    Component.onCompleted: if (editor.ledName.length === 0 && editor.names.length > 0)
        editor.ledName = editor.defaultName()

    Connections {
        target: ThinkPad
        function onLedsAllChanged() {
            if (editor.names.length === 0)
                return;
            if (editor.ledName.length === 0 || editor.names.indexOf(editor.ledName) < 0)
                editor.ledName = editor.defaultName();
        }
    }

    function defaultName() {
        var preferred = ["tpacpi::lid_logo_dot", "tpacpi::kbd_backlight",
                         "platform::micmute", "platform::mute"];
        for (var i = 0; i < preferred.length; i++)
            if (names.indexOf(preferred[i]) >= 0)
                return preferred[i];
        return names[0];
    }

    Text {
        text: editor.ledName.length > 0 ? editor.ledName : "LED"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 8.5 * editor.s
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.2 * editor.s
    }

    ThinkPadChips {
        s: editor.s
        width: editor.width
        options: editor.names
        value: editor.ledName
        onPicked: (v) => editor.ledName = v
    }

    Item {
        width: editor.width
        height: 26 * editor.s

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Brightness"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11.5 * editor.s
            font.weight: Font.Medium
        }

        ScrubValue {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            s: editor.s
            value: editor.live
            from: 0
            to: Math.max(1, editor.max)
            step: 1
            enabled: editor.surface && !editor.surface.busy
            onEdited: (v) => editor.surface.setLedRaw(editor.ledName, v)
        }
    }

    Item {
        width: editor.width
        height: 26 * editor.s

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Trigger"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11.5 * editor.s
            font.weight: Font.Medium
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: editor.currentTrigger
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9 * editor.s
        }
    }

    ThinkPadChips {
        s: editor.s
        width: editor.width
        visible: editor.triggers.length > 0
        options: editor.triggers
        value: editor.currentTrigger
        onPicked: (v) => editor.surface.setLedTrigger(editor.ledName, v)
    }

    Column {
        width: editor.width
        spacing: 2 * editor.s
        visible: editor.timerAvailable && editor.currentTrigger === "timer"

        Text {
            text: "Blink timing (timer trigger)"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 8.5 * editor.s
            font.weight: Font.Medium
        }

        Item {
            width: parent.width
            height: 24 * editor.s

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "On / off — ms"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * editor.s
            }

            ScrubValue {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                s: editor.s
                value: editor.meta.delayOn || 0
                from: 0
                to: 5000
                step: 50
                unit: "ms"
                enabled: editor.surface && !editor.surface.busy
                onEdited: (v) => editor.surface.setLedDelay(editor.ledName, v, editor.meta.delayOff || 0)
            }
        }

        Item {
            width: parent.width
            height: 24 * editor.s

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Off / on — ms"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * editor.s
            }

            ScrubValue {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                s: editor.s
                value: editor.meta.delayOff || 0
                from: 0
                to: 5000
                step: 50
                unit: "ms"
                enabled: editor.surface && !editor.surface.busy
                onEdited: (v) => editor.surface.setLedDelay(editor.ledName, editor.meta.delayOn || 0, v)
            }
        }
    }

    Text {
        width: editor.width
        visible: editor.selected !== null && editor.triggers.length === 0
        text: "No trigger metadata. Install the updated helper with sudo tools/install-extras.sh to expose trigger, pulse and blink controls."
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 8.5 * editor.s
        wrapMode: Text.WordWrap
    }

    Text {
        width: editor.width
        visible: !editor.timerAvailable || editor.currentTrigger !== "timer"
        text: editor.timerAvailable
            ? "Select the timer trigger to expose the blink timing fields."
            : "The kernel exposes no timer/heartbeat trigger for this LED. Brightness and the triggers above are still available."
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 8.5 * editor.s
        wrapMode: Text.WordWrap
    }

    Text {
        width: editor.width
        visible: editor.notice.length > 0
        text: editor.notice
        color: Theme.flameCore
        font.family: Theme.font
        font.pixelSize: 9 * editor.s
        wrapMode: Text.WordWrap
    }
}
