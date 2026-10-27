pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/** Lighting group: the three primary LEDs plus every remaining LED in the EC. */
ThinkPadGroup {
    id: lighting

    property var surface: null

    title: "Lighting"
    open: true

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
        label: "Lid logo"
        visible: ThinkPad.leds.LIDLOGO !== undefined

        LinkToggle {
            s: lighting.s
            on: (ThinkPad.leds.LIDLOGO || 0) > 0
            enabled: !lighting.surface.busy
            onToggled: lighting.surface.setLed("lid", !on)
        }
    }

    SettingsField {
        surface: lighting.surface
        label: "Vantage"
        visible: ThinkPad.leds.VANTAGE !== undefined

        LinkToggle {
            s: lighting.s
            on: (ThinkPad.leds.VANTAGE || 0) > 0
            enabled: !lighting.surface.busy
            onToggled: lighting.surface.setLed("vantage", !on)
        }
    }

    ThinkPadGroup {
        s: lighting.s
        title: "All LEDs"
        open: false
        visible: ThinkPad.ledOther.length > 0

        Repeater {
            model: ThinkPad.ledOther

            SettingsField {
                id: ledRow
                required property var modelData
                surface: lighting.surface
                label: lighting.ledLabel(ledRow.modelData.name)

                LinkToggle {
                    s: lighting.s
                    on: ledRow.modelData.value > 0
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
                text: "Firmware or the NIC can take these indicators back; the write still confirms the current state."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 8.5 * lighting.s
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }
        }
    }

    function ledLabel(name) {
        switch (name) {
        case "platform::micmute": return "Mic mute";
        case "platform::mute": return "Speaker mute";
        case "tpacpi::power": return "Power LED";
        case "tpacpi::standby": return "Standby LED";
        case "input3::capslock": return "Caps Lock";
        case "input3::numlock": return "Num Lock";
        case "input3::scrolllock": return "Scroll Lock";
        case "tpacpi::fnlock": return "Fn lock";
        case "platform::fnlock": return "Fn lock";
        }
        if (name.indexOf("::lan") >= 0)
            return "LAN " + name.replace("enp1s0-", "").replace("::lan", "");
        return name;
    }
}
