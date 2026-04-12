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

    property string vmState: "unknown"
    property bool simRunning: false

    width: isVertical ? widgetThickness : (vmIcon.width + horizontalPadding * 2)
    height: isVertical ? (vmIcon.height + horizontalPadding * 2) : widgetThickness
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) return "transparent"
        const baseColor = mouseArea.containsMouse
            ? stateColor
            : Qt.darker(stateColor, 1.3)
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
    }

    readonly property color stateColor: {
        switch (vmState) {
            case "running": return "#4CAF50"
            case "paused": return "#FF9800"
            case "shut off": return Theme.widgetBaseHoverColor
            case "crashed": return "#F44336"
            default: return Theme.widgetBaseBackgroundColor
        }
    }

    DankIcon {
        id: vmIcon
        anchors.centerIn: parent
        name: "computer"
        size: Theme.barIconSize(barThickness, -4)
        color: vmState === "running" ? "#FFFFFF" : Theme.surfaceText
    }

    // Small sim indicator dot
    Rectangle {
        visible: simRunning
        width: 6; height: 6; radius: 3
        color: "#4CAF50"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 2
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                // Right-click: toggle activity sim
                simToggleProcess.running = true
            } else {
                // Left-click: open console if running, start if stopped
                if (vmState === "running") {
                    consoleProcess.running = true
                } else if (vmState === "shut off" || vmState === "unknown") {
                    startProcess.running = true
                }
            }
        }
    }

    // Processes
    Process {
        id: statusProcess
        command: ["work-vm", "status"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.vmState = JSON.parse(data).state || "unknown"
                } catch (e) {}
            }
        }
    }

    Process {
        id: simStatusProcess
        command: ["activity-sim", "status"]
        stdout: SplitParser {
            onRead: data => {
                try { root.simRunning = JSON.parse(data).running } catch (e) {}
            }
        }
    }

    Process { id: startProcess; command: ["work-vm", "start"] }
    Process { id: consoleProcess; command: ["work-vm", "console"] }

    Process {
        id: simToggleProcess
        command: ["activity-sim", "toggle"]
        stdout: SplitParser {
            onRead: data => {
                try { root.simRunning = JSON.parse(data).running } catch (e) {}
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            statusProcess.running = true
            simStatusProcess.running = true
        }
    }

    Component.onCompleted: {
        statusProcess.running = true
        simStatusProcess.running = true
    }
}
