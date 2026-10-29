pragma Singleton
import QtQuick
import Quickshell

/**
 * System-event notices: battery/charger, battery full, microphone state and
 * (from Peripherals) low peripheral batteries. Key notices have their own
 * pipeline in KeyNotice; these are intentionally separate so either can be
 * disabled without silencing the other.
 */
Singleton {
    id: root

    signal notice(string icon, string label, string value)

    property bool armed: false
    property bool lowLatched: false
    property bool fullLatched: false
    property bool micReady: false
    property bool micWasPresent: false
    property bool micWasMuted: false
    property string micName: ""

    function send(icon, label, value) {
        if (!root.armed)
            return;
        root.notice(icon, label, value);
    }

    function checkBattery() {
        if (!root.armed || !Battery.present)
            return;
        var p = Battery.pct;
        var threshold = Math.max(5, Math.min(15, Flags.notifyBatteryLowPct));
        if (Battery.charging || p > threshold + 2)
            root.lowLatched = false;
        if (!Battery.charging && p > 0 && p <= threshold && !root.lowLatched) {
            root.lowLatched = true;
            if (Flags.notifyBatteryLow)
                root.send("bolt", "Battery low", p + "% · charge soon");
        }
        if (Battery.full) {
            if (!root.fullLatched) {
                root.fullLatched = true;
                if (Flags.notifyBatteryFull)
                    root.send("bolt", "Battery full", "Plugged in · 100%");
            }
        } else {
            root.fullLatched = false;
        }
    }

    function checkMic() {
        if (!root.armed)
            return;
        var source = Sound.source;
        var present = source !== null && source !== undefined;
        var muted = present && source.audio ? source.audio.muted : false;
        var name = present ? String(source.name || source.description || "Microphone") : "";
        if (!root.micReady) {
            root.micReady = true;
            root.micWasPresent = present;
            root.micWasMuted = muted;
            root.micName = name;
            return;
        }
        if (present !== root.micWasPresent) {
            if (Flags.notifyMicPlug) {
                root.send("mic", "Microphone",
                    present ? "Connected · " + name : "Disconnected");
            }
            root.micWasPresent = present;
            root.micWasMuted = muted;
            root.micName = name;
            return;
        }
        if (present && muted !== root.micWasMuted) {
            root.micWasMuted = muted;
            if (Flags.notifyMicMute)
                root.send("mic", "Microphone", muted ? "Muted" : "Live");
        }
        root.micName = name;
    }

    Connections {
        target: Battery
        enabled: Battery.present
        function onPctChanged() { root.checkBattery(); }
        function onChargingChanged() {
            if (!root.armed)
                return;
            if (Flags.notifyCharger) {
                root.send("bolt", "Charger",
                    Battery.charging ? "Connected · " + Battery.pct + "%"
                    : "Unplugged · on battery");
            }
            root.checkBattery();
        }
        function onFullChanged() { root.checkBattery(); }
    }

    Connections {
        target: Sound
        function onSourceChanged() { root.checkMic(); }
    }

    Connections {
        target: Sound.source && Sound.source.audio ? Sound.source.audio : null
        function onMutedChanged() { root.checkMic(); }
    }

    /** Baseline the initial state without firing on login/restart. */
    Timer {
        interval: 1800
        running: true
        onTriggered: {
            root.armed = true;
            root.lowLatched = Battery.present && !Battery.charging
                && Battery.pct <= Flags.notifyBatteryLowPct;
            root.fullLatched = Battery.full;
            root.checkMic();
            root.checkBattery();
        }
    }
}
