import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import PdM.Core

/*
 * The AI Agent tab.
 *
 * An Item, not an ApplicationWindow -- see docs/INTEGRATION_CONTRACT.md in the
 * Maestro repo. Written against the contract from the start, same shape as
 * pdm_mlops_gui.
 *
 * This is A1 of docs/SCOPE.md: two deterministic, hard-coded views -- no
 * model, no retrieval, no network -- that satisfy "describe the system" and
 * "show the lifecycle" with zero hallucination risk. Everything rendered here
 * is data in this file, not text a language model generated; A2 is what adds
 * the part that can be wrong.
 */
Item {
    id: root

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        z: -1
    }

    Material.theme: Theme.dark ? Material.Dark : Material.Light
    Material.accent: Theme.primary

    property int currentView: 0   // 0 = system map, 1 = lifecycle, 2 = settings

    AgentClient { id: assistant }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        spacing: Theme.spacing

        /* ---------------------------------------------------------------- */
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing

            ColumnLayout {
                spacing: 2
                Text {
                    text: qsTr("AI Agent")
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
                Text {
                    text: qsTr("Developer assistant for the PdM toolchain — read-only, no model yet")
                    font.pixelSize: Theme.fontSmall
                    color: Theme.textSecondary
                }
            }

            Item { Layout.fillWidth: true }

            TabBar {
                id: viewSwitch
                currentIndex: root.currentView
                onCurrentIndexChanged: root.currentView = currentIndex

                TabButton { text: qsTr("System Map") }
                TabButton { text: qsTr("Lifecycle") }
                TabButton { text: qsTr("Settings") }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.outline
        }

        /* ---------------------------------------------------------------- */
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.currentView

            SystemMapView {}
            LifecycleView {}
            SettingsView { assistant: assistant }
        }
    }
}
