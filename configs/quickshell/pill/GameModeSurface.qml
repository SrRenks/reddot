import QtQuick
import "Singletons"

/** Target-aware game mode: choose a window, keep a few apps, tame the desktop. */
PillSurface {
    id: root

    mTop: 14
    mLeft: 18
    mRight: 18
    mBottom: 14

    implicitHeight: content.implicitHeight

    onOpenChanged: if (open) GameMode.refreshWindows()

    Column {
        id: content
        width: parent.width
        spacing: 0

        SettingsHeader {
            s: root.s
            icon: "gamepad"
            glyphColor: Theme.vermLit
            title: "GAME MODE"
            showBack: true
        }

        Text {
            width: parent.width
            topPadding: 7 * root.s
            bottomPadding: 5 * root.s
            text: "Pick the game window and keep the apps you still need. Other user windows can receive SIGTERM after confirmation; system services and the game tree are never candidates."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: Typography.size("caption", root.s)
            wrapMode: Text.WordWrap
        }

        SettingsLabel { s: root.s; text: "Windows" }

        Repeater {
            model: GameMode.windows

            GameModeWindowRow {
                required property var modelData
                s: root.s
                app: modelData
                target: GameMode.isTarget(modelData)
                kept: GameMode.isKept(modelData)
                onPicked: GameMode.chooseWindow(modelData)
                onKeepChanged: (on) => GameMode.setKept(modelData, on)
            }
        }

        Text {
            visible: GameMode.windows.length === 0
            width: parent.width
            topPadding: 8 * root.s
            bottomPadding: 8 * root.s
            text: "No mapped windows found."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: Typography.size("body", root.s)
        }

        Item {
            width: parent.width
            height: 38 * root.s

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Close other apps"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: Typography.size("body", root.s)
                font.weight: Font.Medium
            }

            LinkToggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                on: Flags.gameModeKillOthers
                onToggled: Flags.gameModeKillOthers = !Flags.gameModeKillOthers
            }
        }

        Text {
            visible: Flags.gameModeKillOthers
            width: parent.width
            bottomPadding: 6 * root.s
            text: "On Start, non-kept windows receive SIGTERM. Keep Discord, the browser and anything with unsaved work. No system service is targeted."
            color: Theme.flameCore
            font.family: Theme.font
            font.pixelSize: Typography.size("micro", root.s)
            wrapMode: Text.WordWrap
        }

        Item {
            width: parent.width
            height: 38 * root.s

            ChipButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                text: GameMode.active ? "Stop" : (GameMode.busy ? "Working…" : "Start")
                onClicked: GameMode.active ? GameMode.stopGame() : GameMode.startGame()
            }

            ChipButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                text: "Refresh"
                onClicked: GameMode.refreshWindows()
            }
        }

        Text {
            visible: GameMode.cleanupOutput.length > 0
            width: parent.width
            topPadding: 4 * root.s
            text: GameMode.cleanupOutput
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: Typography.size("micro", root.s)
            wrapMode: Text.WordWrap
        }
    }
}
