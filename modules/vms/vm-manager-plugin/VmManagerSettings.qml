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
            text: "VM Manager"
            font.pixelSize: 18
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        Text {
            text: "Manages the work-ubuntu VM with status monitoring, controls, and activity simulation. Uses the work-vm CLI for all operations."
            font.pixelSize: 13
            color: Theme.subtitleText
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Text {
            text: "VM Configuration"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.surfaceText
        }

        Text {
            text: "Name: work-ubuntu\nIP: 192.168.122.100\nUser: user\nShared Dir: ~/Documents/shared <-> /mnt/host"
            font.pixelSize: 12
            font.family: "Fira Code"
            color: Theme.subtitleText
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Text {
            text: "CLI Reference"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.surfaceText
        }

        Text {
            text: "Run 'work-vm --help' in a terminal for the full command reference.\n\nActivity sim env vars:\n  ACTIVITY_SIM_HOST (default: 192.168.122.100)\n  ACTIVITY_SIM_USER (default: user)"
            font.pixelSize: 12
            font.family: "Fira Code"
            color: Theme.subtitleText
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }
}
