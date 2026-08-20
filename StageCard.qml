import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PdM.Core

/*
 * One pipeline stage, as a card. Used by LifecycleView.
 *
 * Same shape as RepoCard but with a "writes" line instead of a branch, and a
 * status tag that can read something other than plain "stage" -- see
 * LifecycleView's "provisional" note on the gate stage.
 */
Rectangle {
    id: card

    required property string stageName
    required property string role
    required property string writes
    required property string status   // "stage" or "provisional"
    required property string docPath

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + Theme.spacing * 2
    color: Theme.surface
    border.color: card.status === "provisional" ? Theme.warning : Theme.outline
    border.width: 1
    radius: Theme.radius

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacing
        spacing: Theme.spacingTight

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingTight

            Text {
                text: card.stageName
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontMedium
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }

            Rectangle {
                visible: card.status === "provisional"
                implicitWidth: statusText.implicitWidth + Theme.spacingTight * 2
                implicitHeight: statusText.implicitHeight + 4
                radius: Theme.radiusSmall
                color: Theme.warningSoft
                Text {
                    id: statusText
                    anchors.centerIn: parent
                    text: qsTr("path uncertain — confirm")
                    font.pixelSize: Theme.fontTiny
                    color: Theme.warning
                }
            }

            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.fillWidth: true
            text: card.role
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSmall
            color: Theme.textSecondary
        }

        Text {
            Layout.fillWidth: true
            visible: card.writes.length > 0
            text: qsTr("writes: ") + card.writes
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontTiny
            color: Theme.textDisabled
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingTight

            Text {
                Layout.fillWidth: true
                text: card.docPath
                elide: Text.ElideMiddle
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontTiny
                color: Theme.textDisabled
            }

            Button {
                text: qsTr("Open docs")
                flat: true
                onClicked: Qt.openUrlExternally("file://" + card.docPath)
            }
        }
    }
}
