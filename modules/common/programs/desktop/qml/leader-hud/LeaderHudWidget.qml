import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

BasePill {
    id: root

    property var pluginService: null

    readonly property string home: Quickshell.env("HOME")
    property string activeSubmap: ""
    property var submapMeta: ({})

    readonly property var meta: submapMeta[activeSubmap] ?? null
    readonly property string indicatorIcon: meta?.icon ?? ""
    readonly property string indicatorLabel: indicatorIcon === "" ? (meta?.name ?? meta?.key ?? "") : ""

    visible: activeSubmap.length > 0 && meta !== null
    enableBackgroundHover: false
    enableCursor: false

    FileView {
        id: stateView
        path: root.home + "/.cache/leader-hud/state"
        watchChanges: true
        printErrors: false
        onLoaded: root.activeSubmap = stateView.text().trim()
        onLoadFailed: root.activeSubmap = ""
    }

    FileView {
        id: metaView
        path: root.home + "/.config/leader-hud/submaps.json"
        watchChanges: true
        printErrors: true
        onLoaded: {
            try {
                root.submapMeta = JSON.parse(metaView.text())
            } catch (e) {
                console.warn("LeaderHud: submaps.json parse failed:", e)
                root.submapMeta = ({})
            }
        }
    }

    // inotify can miss a single rewrite from `echo > file` on some filesystems.
    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: stateView.reload()
    }

    // Cheatsheet overlay: pinned top-left under the bar, lists the active
    // submap's key → label pairs. Non-focusable, non-clickable, transparent
    // background. Reuses root.meta from the FileView watchers above.
    PanelWindow {
        id: cheatsheet
        visible: root.visible && (root.meta?.slots?.length ?? 0) > 0
        color: "transparent"

        WlrLayershell.namespace: "leader-hud:cheatsheet"
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: 0

        anchors {
            top: true
            left: true
        }
        margins.top: 48
        margins.left: 12

        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight

        Rectangle {
            id: panel
            anchors.fill: parent
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            implicitWidth: rows.implicitWidth + 24
            implicitHeight: rows.implicitHeight + 16

            Column {
                id: rows
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: root.meta?.slots ?? []
                    delegate: Row {
                        spacing: 10

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 4
                            color: Theme.primaryContainer

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData.key
                                color: Theme.onPrimaryContainer
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }
        }
    }

    content: Component {
        Item {
            implicitWidth: indicator.visible ? indicator.implicitWidth : labelText.implicitWidth
            implicitHeight: indicator.visible ? indicator.implicitHeight : labelText.implicitHeight

            DankIcon {
                id: indicator
                anchors.centerIn: parent
                visible: root.indicatorIcon !== ""
                name: root.indicatorIcon
                size: Theme.barIconSize(root.barThickness, -4)
                color: Theme.surfaceText
            }

            StyledText {
                id: labelText
                anchors.centerIn: parent
                visible: !indicator.visible && root.indicatorLabel !== ""
                text: root.indicatorLabel
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
            }
        }
    }
}
