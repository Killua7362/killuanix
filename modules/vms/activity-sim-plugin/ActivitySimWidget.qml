import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetThickness: 30
    property var pluginService: null
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))

    property bool simRunning: false

    width: isVertical ? widgetThickness : (simIcon.width + horizontalPadding * 2)
    height: isVertical ? (simIcon.height + horizontalPadding * 2) : widgetThickness
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) return "transparent"
        const baseColor = mouseArea.containsMouse
            ? (simRunning ? Theme.primaryColor : Theme.widgetBaseHoverColor)
            : (simRunning ? Qt.darker(Theme.primaryColor, 1.3) : Theme.widgetBaseBackgroundColor)
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
    }

    DankIcon {
        id: simIcon
        anchors.centerIn: parent
        name: "smart_toy"
        size: Theme.barIconSize(barThickness, -4)
        color: simRunning ? Theme.onPrimaryColor : Theme.surfaceText
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggleProcess.running = true
    }

    Process {
        id: toggleProcess
        command: ["activity-sim", "toggle"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.simRunning = JSON.parse(data).running
                } catch (e) {}
            }
        }
    }

    Process {
        id: statusProcess
        command: ["activity-sim", "status"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.simRunning = JSON.parse(data).running
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: statusProcess.running = true
    }

    Component.onCompleted: statusProcess.running = true
}
