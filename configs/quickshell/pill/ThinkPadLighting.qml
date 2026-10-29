pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/** Lighting: keyboard, primary indicators, mute followers and every other LED. */
ThinkPadGroup {
    id: lighting

    property var surface: null

    title: "Lighting"

    Timer {
        id: muteRefresh
        interval: 180
        repeat: false
        onTriggered: ThinkPad.refresh()
    }

    SettingsField {
        surface: lighting.surface
        label: "Keyboard light"
        visible: ThinkPad.kbd >= 0

        SettingsSeg {
            s: lighting.s
            options: ThinkPad.kbdMax >= 2
                ? [{ label: "Off", value: 0 }, { label: "Dim", value: 1 }, { label: "Full", value: 2 }]
                : [{ label: "Off", value: 0 }, { label: "On", value: 1 }]
            value: ThinkPad.kbd
            enabled: !lighting.surface.busy
            onPicked: (v) => lighting.surface.setKbd(v)
        }
    }

    SettingsField {
        surface: lighting.surface
        label: "Mic mute"
        caption: "Audio capture mute · drives the mic-mute LED"
        visible: Sound.source !== null && Sound.source.audio !== null

        LinkToggle {
            s: lighting.s
            on: Sound.source && Sound.source.audio ? Sound.source.audio.muted : false
            enabled: !lighting.surface.busy
            onToggled: {
                if (Sound.source && Sound.source.audio)
                    Sound.source.audio.muted = !on;
                muteRefresh.restart();
            }
        }
    }

    SettingsField {
        surface: lighting.surface
        label: "Speaker mute"
        caption: "Audio output mute · drives the mute LED"
        visible: Sound.sink !== null && Sound.sink.audio !== null

        LinkToggle {
            s: lighting.s
            on: Sound.sink && Sound.sink.audio ? Sound.sink.audio.muted : false
            enabled: !lighting.surface.busy
            onToggled: {
                if (Sound.sink && Sound.sink.audio)
                    Sound.sink.audio.muted = !on;
                muteRefresh.restart();
            }
        }
    }

    SettingsField {
        surface: lighting.surface
        label: "Lid logo"
        caption: "Firmware/EC may own this indicator; state follows the lit lid"
        visible: ThinkPad.leds.LIDLOGO !== undefined

        LinkToggle {
            s: lighting.s
            on: ThinkPad.ledOn("tpacpi::lid_logo_dot", ThinkPad.leds.LIDLOGO || 0)
            enabled: !lighting.surface.busy
            onToggled: lighting.surface.setLed("lid", !on)
        }
    }

    SettingsField {
        surface: lighting.surface
        label: "Lid logo brightness"
        caption: "Software brightness; firmware may keep the logo lit independently"
        visible: ThinkPad.leds.LIDLOGO !== undefined

        ScrubValue {
            s: lighting.s
            value: ThinkPad.ledValue("tpacpi::lid_logo_dot", ThinkPad.leds.LIDLOGO || 0)
            from: 0
            to: Math.max(1, lighting.lidMax())
            step: 1
            enabled: !lighting.surface.busy
            onEdited: (v) => lighting.surface.setLedRaw("tpacpi::lid_logo_dot", v)
        }
    }

    SettingsField {
        surface: lighting.surface
        label: "Vantage"
        visible: ThinkPad.leds.VANTAGE !== undefined

        LinkToggle {
            s: lighting.s
            on: ThinkPad.ledValue("tpacpi::thinkvantage", ThinkPad.leds.VANTAGE || 0) > 0
            enabled: !lighting.surface.busy
            onToggled: lighting.surface.setLed("vantage", !on)
        }
    }

    Repeater {
        model: ThinkPad.ledOther

        SettingsField {
            id: ledRow
            required property var modelData
            surface: lighting.surface
            label: lighting.ledLabel(ledRow.modelData.name)
            caption: ledRow.modelData.name === "tpacpi::power"
                ? "Firmware-controlled; sysfs can read 0 while the LED is lit"
                : (ledRow.modelData.name === "tpacpi::lid_logo_dot"
                    ? "Firmware/EC may own the lid logo on this model"
                    : "")

            LinkToggle {
                s: lighting.s
                on: ThinkPad.ledOn(ledRow.modelData.name, ledRow.modelData.value)
                enabled: !lighting.surface.busy
                onToggled: lighting.surface.setLedRaw(
                    ledRow.modelData.name,
                    !on ? ledRow.modelData.max : 0)
            }
        }
    }

    Item {
        width: parent.width
        height: note.implicitHeight + 8 * lighting.s

        Text {
            id: note
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 2 * lighting.s
            text: "LED state follows the kernel/hardware while this surface is open. Lock LEDs indicate the key state; writing the LED does not toggle Caps/Num/Scroll. Firmware or the NIC can reclaim an indicator."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: Typography.size("micro", lighting.s)
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
        }
    }

    function lidMax() {
        for (var i = 0; i < ThinkPad.ledsAll.length; i++)
            if (ThinkPad.ledsAll[i].name === "tpacpi::lid_logo_dot")
                return ThinkPad.ledsAll[i].max || 1;
        return 1;
    }

    function ledLabel(name) {
        switch (name) {
        case "platform::micmute": return "Mic mute LED";
        case "platform::mute": return "Speaker mute LED";
        case "tpacpi::power": return "Power LED";
        case "tpacpi::standby": return "Standby LED";
        case "input3::capslock": return "Caps Lock LED";
        case "input3::numlock": return "Num Lock LED";
        case "input3::scrolllock": return "Scroll Lock LED";
        case "tpacpi::fnlock": return "Fn lock";
        case "platform::fnlock": return "Fn lock";
        }
        if (name.indexOf("::lan") >= 0)
            return "LAN " + name.replace("enp1s0-", "").replace("::lan", "");
        return name;
    }
}
