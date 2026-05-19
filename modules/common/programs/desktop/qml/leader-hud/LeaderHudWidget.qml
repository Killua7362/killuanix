import QtQuick
import Quickshell
import Quickshell.Io
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
