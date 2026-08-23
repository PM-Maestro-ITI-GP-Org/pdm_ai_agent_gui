import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PdM.Core

/*
 * One repository, as a card. Used by SystemMapView, which lays these out as
 * nodes on a small architecture diagram (a spine + connector rail drawn in
 * the view, not here) rather than a plain list.
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

    /* The firmware entry isn't code this toolchain owns -- it's reached over
       USB serial, not pulled in as a submodule -- so it reads in a cooler,
       secondary tone. Everything else (hub, submodule) reads as "this repo". */
    readonly property bool isExternal: card.kind === "firmware"
    readonly property bool isHub: card.kind === "hub"
    readonly property color accentColor: card.isExternal ? Theme.textSecondary : Theme.primary

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + Theme.spacing * 2
    color: Theme.surface
    border.color: hover.hovered ? Theme.primary : (card.isHub ? Theme.primary : Theme.outline)
    border.width: card.isHub ? 2 : 1
    radius: Theme.radius

    Behavior on border.color { ColorAnimation { duration: 150 } }

    HoverHandler { id: hover }

    /* A small floating accent bar rather than a full-bleed edge -- it reads
       as a tag, not a construction seam, and stays clear of the rounded
       corners above and below it. */
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
                text: card.repoName
                font.pixelSize: Theme.fontMedium
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }

            Rectangle {
                implicitWidth: kindText.implicitWidth + Theme.spacingTight * 2
                implicitHeight: kindText.implicitHeight + 4
                radius: Theme.radiusSmall
                color: card.isExternal ? Theme.neutralSoft : Theme.primarySoft
                Text {
                    id: kindText
                    anchors.centerIn: parent
                    text: card.kind
                    font.pixelSize: Theme.fontTiny
                    color: card.isExternal ? Theme.textSecondary : Theme.primary
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
