import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PdM.Core

/*
 * One repository, as a card. Used by SystemMapView.
 *
 * "Open docs" shells out to the OS's own file handler via
 * Qt.openUrlExternally -- no in-app markdown renderer exists yet, and
 * reaching for one before there is a second reason to would be exactly the
 * kind of unrequested abstraction docs/SCOPE.md's phase plan tries to avoid.
 */
Rectangle {
    id: card

    required property string repoName
    required property string role
    required property string branch
    required property string kind      // e.g. "hub", "submodule", "firmware"
    required property string docPath   // absolute path to open

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + Theme.spacing * 2
    color: Theme.surface
    border.color: Theme.outline
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
                text: card.repoName
                font.pixelSize: Theme.fontMedium
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }

            Rectangle {
                implicitWidth: kindText.implicitWidth + Theme.spacingTight * 2
                implicitHeight: kindText.implicitHeight + 4
                radius: Theme.radiusSmall
                color: Theme.primarySoft
                Text {
                    id: kindText
                    anchors.centerIn: parent
                    text: card.kind
                    font.pixelSize: Theme.fontTiny
                    color: Theme.primary
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: card.branch
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontTiny
                color: Theme.textDisabled
            }
        }

        Text {
            Layout.fillWidth: true
            text: card.role
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSmall
            color: Theme.textSecondary
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
