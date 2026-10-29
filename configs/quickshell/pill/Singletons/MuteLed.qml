pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Mute indicators on ThinkPads are not connected to PipeWire's node mute.
 * brightnessctl can write them without root on this platform, so follow the
 * audio state: mute keys, mixer toggles and the OSD all settle here.
 */
Singleton {
    id: root

    property bool micKnown: false
    property bool micOn: false
    property bool sinkKnown: false
    property bool sinkOn: false

    function setMic(on) {
        if (root.micKnown && root.micOn === on)
            return;
        root.micKnown = true;
        root.micOn = on;
        if (!micProc.running) {
            micProc.command = ["brightnessctl", "--device", "platform::micmute", "set", on ? "1" : "0"];
            micProc.running = true;
        }
    }

    function setSink(on) {
        if (root.sinkKnown && root.sinkOn === on)
            return;
        root.sinkKnown = true;
        root.sinkOn = on;
        if (!sinkProc.running) {
            sinkProc.command = ["brightnessctl", "--device", "platform::mute", "set", on ? "1" : "0"];
            sinkProc.running = true;
        }
    }

    function syncAll() {
        root.setMic(Sound.source && Sound.source.audio ? Sound.source.audio.muted : false);
        root.setSink(Sound.sink && Sound.sink.audio ? Sound.sink.audio.muted : false);
    }

    Connections {
        target: Sound
        function onSourceChanged() { root.syncAll(); }
        function onSinkChanged() { root.syncAll(); }
    }

    Connections {
        target: Sound.source && Sound.source.audio ? Sound.source.audio : null
        function onMutedChanged() { root.syncAll(); }
    }

    Connections {
        target: Sound.sink && Sound.sink.audio ? Sound.sink.audio : null
        function onMutedChanged() { root.syncAll(); }
    }

    Process { id: micProc }
    Process { id: sinkProc }
}
