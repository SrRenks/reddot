pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"
import "lib/navigation.js" as Navigation
import "lib/search.js" as SearchEngine

/**
 * Find a page by title, alias or tag. The page list comes from the navigation
 * manifest; the ranking is the pure SearchEngine so the result order matches the
 * Node tests. The Search surface is hidden from its own results.
 */
PillSurface {
    id: root

    property var results: []
    property int selected: -1

    implicitHeight: content.implicitHeight
    focus: true
    activeFocusOnTab: true
    mTop: 15
    mLeft: 19
    mRight: 19
    mBottom: 16

    signal requestSurface(string name)

    readonly property var pages: {
        var out = [];
        var ids = Navigation.allPageIds();
        for (var i = 0; i < ids.length; i++) {
            var entry = Navigation.pageInfo(ids[i]);
            if (entry.hidden)
                continue;
            if (entry.available === "thinkpad" && !ThinkPad.present)
                continue;
            out.push(entry);
        }
        return out;
    }

    function refresh() {
        root.results = SearchEngine.rank(root.pages, query.text, 8);
        root.selected = root.results.length > 0 ? 0 : -1;
    }

    function openResult(entry) {
        if (!entry)
            return false;
        root.requestSurface(entry.id);
        return true;
    }

    function pick() {
        return root.openResult(root.results[root.selected]);
    }

    function moveSelection(dir) {
        if (root.results.length === 0)
            return;
        root.selected = Math.max(0, Math.min(root.results.length - 1, root.selected + dir));
    }

    onOpenChanged: {
        if (open) {
            query.text = "";
            root.results = [];
            root.selected = -1;
            root.forceActiveFocus();
            Qt.callLater(() => query.forceActiveFocus());
        }
    }

    Keys.onReturnPressed: root.openResult(root.results[root.selected])
    Keys.onEnterPressed: root.openResult(root.results[root.selected])
    Keys.onDownPressed: root.moveSelection(1)
    Keys.onUpPressed: root.moveSelection(-1)

    Column {
        id: content
        width: parent.width
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "捜"
            title: "SEARCH"
            showBack: true
        }

        Item { width: 1; height: 8 * root.s }

        TextInput {
            id: query
            width: parent.width
            height: 34 * root.s
            leftPadding: 12 * root.s
            rightPadding: 12 * root.s
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 14 * root.s
            font.letterSpacing: 0.5 * root.s
            focus: true
            selectByMouse: true
            clip: true
            Keys.onDownPressed: root.moveSelection(1)
            Keys.onUpPressed: root.moveSelection(-1)
            onTextChanged: root.refresh()
            onAccepted: root.openResult(root.results[root.selected])
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                        || event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        root.openResult(root.results[root.selected]);
                    else
                        root.moveSelection(event.key === Qt.Key_Down ? 1 : -1);
                    event.accepted = true;
                }
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: 12 * root.s
                verticalAlignment: Text.AlignVCenter
                visible: query.text.length === 0
                text: "Search pages, settings and controls…"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 13 * root.s
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Item { width: 1; height: 6 * root.s }

        Repeater {
            model: root.results

            delegate: Item {
                id: result
                required property var modelData
                required property int index
                width: content.width
                height: 42 * root.s
                readonly property bool focused: root.selected === result.index

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 1 * root.s
                    anchors.bottomMargin: 1 * root.s
                    radius: 8 * root.s
                    color: result.focused ? Qt.alpha(Theme.vermLit, 0.10) : "transparent"
                    border.width: result.focused ? 1 : 0
                    border.color: Qt.alpha(Theme.vermLit, 0.35)
                }

                GlyphIcon {
                    anchors.left: parent.left
                    anchors.leftMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16 * root.s
                    height: 16 * root.s
                    name: "search"
                    color: result.focused ? Theme.cream : Theme.subtle
                    stroke: 1.8
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 36 * root.s
                    anchors.right: parent.right
                    anchors.rightMargin: 28 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * root.s

                    Text {
                        width: parent.width
                        text: result.modelData.title
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 12.5 * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: result.modelData.sub.length > 0
                        text: result.modelData.sub
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        elide: Text.ElideRight
                    }
                }

                GlyphIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14 * root.s
                    height: 14 * root.s
                    name: "chevron-right"
                    color: result.focused ? Theme.cream : Theme.iconDim
                    stroke: 2
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: if (containsMouse) root.selected = result.index
                    onClicked: root.openResult(result.modelData)
                }
            }
        }

        Text {
            width: parent.width
            height: 28 * root.s
            visible: query.text.length > 0 && root.results.length === 0
            text: "No matching section"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            width: parent.width
            height: 28 * root.s
            visible: query.text.length === 0
            text: "Type a section, alias or tag"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            verticalAlignment: Text.AlignVCenter
        }

        Item { width: 1; height: 4 * root.s }
    }
}
