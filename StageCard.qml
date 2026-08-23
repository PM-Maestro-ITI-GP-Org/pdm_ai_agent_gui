import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PdM.Core

/*
 * One pipeline stage, as a card. Used by LifecycleView, which lays these out
 * as numbered nodes on a pipeline diagram (the spine, arrows, and step
 * numbers are drawn there, not here) rather than a plain list.
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

    readonly property bool isProvisional: card.status === "provisional"
    readonly property color accentColor: card.isProvisional ? Theme.warning : Theme.primary

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + Theme.spacing * 2
    color: Theme.surface
    border.color: hover.hovered ? Theme.primary : (card.isProvisional ? Theme.warning : Theme.outline)
    border.width: 1
    radius: Theme.radius

    Behavior on border.color { ColorAnimation { duration: 150 } }

    HoverHandler { id: hover }

    /* Same floating accent-bar language as RepoCard -- a deliberate, shared
       motif rather than two ad-hoc treatments for two card types that are
       really the same idea (a node in a diagram) twice. */
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingTight
        width: 3
        radius: 1.5
        color: card.accentColor
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacing
        anchors.leftMargin: Theme.spacing + Theme.spacingTight
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
                visible: card.isProvisional
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
