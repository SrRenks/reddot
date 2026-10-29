pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Shared session flags persisted to a small JSON file and watched for external
 * change, so every reddot daemon (pill, lock) reads and writes the same
 * Do-Not-Disturb and Keep-Awake state live without a second notification server
 * or idle inhibitor. Toggling in one surface updates the others on the next file
 * event, and the state survives a daemon restart.
 */
Singleton {
    id: root

    property alias dnd: adapter.dnd
    property alias keepAwake: adapter.keepAwake
    property alias time12h: adapter.time12h
    property alias clockSeconds: adapter.clockSeconds
    property alias showGlyphs: adapter.showGlyphs
    property alias paletteMode: adapter.paletteMode
    property alias appTheme: adapter.appTheme
    property alias wallpaperDir: adapter.wallpaperDir
    property alias randomScope: adapter.randomScope
    property alias uiScale: adapter.uiScale
    property alias reduceMotion: adapter.reduceMotion
    property alias manualHue: adapter.manualHue
    property alias manualDark: adapter.manualDark
    property alias manualSat: adapter.manualSat
    property alias uiFont: adapter.uiFont
    property alias pillOpacity: adapter.pillOpacity
    property alias pillBlur: adapter.pillBlur
    property alias windowBlur: adapter.windowBlur
    property alias keyNoticeEnabled: adapter.keyNoticeEnabled
    property alias keyNoticeMs: adapter.keyNoticeMs
    property alias notifyBatteryLow: adapter.notifyBatteryLow
    property alias notifyBatteryLowPct: adapter.notifyBatteryLowPct
    property alias notifyCharger: adapter.notifyCharger
    property alias notifyBatteryFull: adapter.notifyBatteryFull
    property alias notifyMicMute: adapter.notifyMicMute
    property alias notifyMicPlug: adapter.notifyMicPlug
    property alias notifyPeripheralLow: adapter.notifyPeripheralLow
    property alias pillMode: adapter.pillMode
    property alias pillReserve: adapter.pillReserve
    property alias topGap: adapter.topGap
    property alias appGap: adapter.appGap
    property alias recordCountdown: adapter.recordCountdown
    property alias recordDir: adapter.recordDir
    property alias recordFps: adapter.recordFps
    property alias recordQuality: adapter.recordQuality
    property alias recordCursor: adapter.recordCursor
    property alias recordMic: adapter.recordMic
    property alias recordDesktop: adapter.recordDesktop
    property alias recordClearedBefore: adapter.recordClearedBefore
    property alias idleLockMin: adapter.idleLockMin
    property alias idleScreenOffMin: adapter.idleScreenOffMin
    property alias idleSuspendMin: adapter.idleSuspendMin
    property alias weatherCity: adapter.weatherCity
    property alias musicViz: adapter.musicViz
    property alias gameMode: adapter.gameMode
    property alias gamePrevDnd: adapter.gamePrevDnd
    property alias gamePrevViz: adapter.gamePrevViz
    property alias gamePrevAwake: adapter.gamePrevAwake
    property alias gamePrevProfile: adapter.gamePrevProfile
    property alias gameModeTargetClass: adapter.gameModeTargetClass
    property alias gameModeKeepClasses: adapter.gameModeKeepClasses
    property alias gameModeKillOthers: adapter.gameModeKillOthers
    property alias nightLightMode: adapter.nightLightMode
    property alias nightLightTemp: adapter.nightLightTemp
    property alias nightLightOnMin: adapter.nightLightOnMin
    property alias nightLightOffMin: adapter.nightLightOffMin
    property alias fxSavedActive: adapter.fxSavedActive
    property alias fxSavedInactive: adapter.fxSavedInactive
    property alias lastSurface: adapter.lastSurface
    property alias barAlign: adapter.barAlign
    property alias barOrder: adapter.barOrder
    property alias barStatusReverse: adapter.barStatusReverse
    property alias barStatusOrder: adapter.barStatusOrder
    property alias barWorkspaces: adapter.barWorkspaces
    property alias barClock: adapter.barClock
    property alias barDate: adapter.barDate
    property alias barWeather: adapter.barWeather
    property alias barMinimized: adapter.barMinimized
    property alias barTray: adapter.barTray
    property alias barDnd: adapter.barDnd
    property alias barNetwork: adapter.barNetwork
    property alias barWifi: adapter.barWifi
    property alias barBt: adapter.barBt
    property alias barBattery: adapter.barBattery
    property alias barInbox: adapter.barInbox
    property alias barMixer: adapter.barMixer
    property alias barSound: adapter.barSound
    property alias barThinkpad: adapter.barThinkpad
    property alias barSysmon: adapter.barSysmon
    property alias barRecorder: adapter.barRecorder
    property alias barSettings: adapter.barSettings
    property alias barPower: adapter.barPower
    property alias barUpdates: adapter.barUpdates
    property alias packageUpdatesEnabled: adapter.packageUpdatesEnabled
    property alias packageCheckMinutes: adapter.packageCheckMinutes
    property alias lockFingerprint: adapter.lockFingerprint

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/reddot/flags.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property bool dnd: false
            property bool keepAwake: false
            property bool time12h: false
            property bool clockSeconds: false
            property bool showGlyphs: true
            property string paletteMode: "static"
            /** GTK apps follow the pill palette. Off by default so an update never restyles apps unasked; the installer turns it on for fresh boxes. */
            property bool appTheme: false
            /** Explicit wallpaper folder override. Empty means autodetect: the dir wallpaper.sh last resolved (reddot-wallpaper-dir state file), then ~/reddot/wallpapers. Lives in user state so an in-app update never clobbers a custom folder. */
            property string wallpaperDir: ""
            /** Super+B random target: "all" repaints every monitor, "cursor" only the one under the pointer. */
            property string randomScope: "all"
            property real uiScale: 1.0
            property bool reduceMotion: false
            property int manualHue: 30
            property bool manualDark: true
            property real manualSat: 0.5
            property string uiFont: ""
            property real pillOpacity: 1.0
            property bool pillBlur: false
            /** Intent for ordinary window blur; panel blur has its own switch. */
            property bool windowBlur: false
            /** Brief pill feedback for keybind changes (keyboard layout, etc.). */
            property bool keyNoticeEnabled: true
            property int keyNoticeMs: 500
            /** System-event notices; independent from key notices. */
            property bool notifyBatteryLow: true
            property int notifyBatteryLowPct: 15
            property bool notifyCharger: true
            property bool notifyBatteryFull: true
            property bool notifyMicMute: true
            property bool notifyMicPlug: true
            property bool notifyPeripheralLow: true
            /** "always" rests the pill on screen; "auto" retracts it and reveals it when the pointer touches the top strip. */
            property string pillMode: "auto"
            /** Reserve the top band so tiled windows start below the pill. Auto mode ignores it (the strip must stay reachable). */
            property bool pillReserve: false
            /** Top margin as a fraction of the shipped 8px. 0 sits the pill flush to the screen edge. */
            property real topGap: 1.0
            /** Pill-to-window band as a fraction of the shipped 12px. 0 tucks the windows flush under the pill. */
            property real appGap: 1.0
            property int recordCountdown: 5
            property string recordDir: ""
            property int recordFps: 60
            property string recordQuality: "high"
            property bool recordCursor: true
            property bool recordMic: true
            property bool recordDesktop: true
            property real recordClearedBefore: 0
            property int idleLockMin: 5
            property int idleScreenOffMin: 6
            property int idleSuspendMin: 0
            property string weatherCity: ""
            property bool musicViz: true
            property bool gameMode: false
            property bool gamePrevDnd: false
            property bool gamePrevViz: true
            property bool gamePrevAwake: false
            property string gamePrevProfile: ""
            property string gameModeTargetClass: ""
            property string gameModeKeepClasses: ""
            property bool gameModeKillOthers: false
            property string nightLightMode: "off"
            property int nightLightTemp: 4000
            property int nightLightOnMin: 1260
            property int nightLightOffMin: 450
            /** What the blur/transparency toggle restores when it is switched back on. */
            property real fxSavedActive: 0.80
            property real fxSavedInactive: 0.50
            /** Last surface opened by the keyboard pill toggle; restored on reopen. */
            property string lastSurface: ""
            /** Main-bar presentation and item visibility. */
            property string barAlign: "center"
            property string barOrder: "standard"
            property bool barStatusReverse: false
            /** Status-cluster order; the Bar page edits this list. */
            property string barStatusOrder: "weather,minimized,tray,dnd,network,inbox,mixer,sound,thinkpad,sysmon,updates,recorder,settings,power"
            property bool barWorkspaces: true
            property bool barClock: true
            property bool barDate: true
            property bool barWeather: true
            property bool barMinimized: true
            property bool barTray: true
            property bool barDnd: true
            property bool barNetwork: true
            property bool barWifi: true
            property bool barBt: true
            property bool barBattery: true
            property bool barInbox: true
            property bool barMixer: true
            property bool barSound: true
            property bool barThinkpad: true
            property bool barSysmon: true
            property bool barRecorder: true
            property bool barSettings: true
            property bool barPower: true
            property bool barUpdates: true
            property bool packageUpdatesEnabled: true
            property int packageCheckMinutes: 60
            /** Allow the lock screen to offer fingerprint authentication when a reader and an enrolled print exist. */
            property bool lockFingerprint: true
        }
    }
}
