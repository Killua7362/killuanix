import QtQuick
import QtQuick.Controls
import qs.Common

FocusScope {
    id: root

    property var pluginService: null

    implicitHeight: settingsColumn.implicitHeight
    height: implicitHeight

    Column {
        id: settingsColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            text: "Activity Simulator"
            font.pixelSize: 18
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        Text {
            text: "Simulates mouse and keyboard activity inside a VM via SSH + xdotool. The activity-sim script must be in PATH and the target VM must be reachable."
            font.pixelSize: 13
            color: Theme.subtitleText
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Text {
            text: "Configure VM host/user via environment variables:\n  ACTIVITY_SIM_HOST (default: 192.168.122.100)\n  ACTIVITY_SIM_USER (default: user)"
            font.pixelSize: 12
            font.family: "Fira Code"
            color: Theme.subtitleText
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }
}
