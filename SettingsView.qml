import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PdM.Core

/*
 * Connection settings for the local AI server (docs/SCOPE.md §6.1, A2a).
 *
 * No question/answer UI here yet -- there is no chat endpoint on the server
 * side yet either. This is connection status and model selection only.
 */
Item {
    id: root

    required property var assistant

    Rectangle {
        Layout.fillWidth: true
        anchors.fill: parent
        color: Theme.surface
        border.color: Theme.outline
        border.width: 1
        radius: Theme.radius
        implicitHeight: content.implicitHeight + Theme.spacing * 2

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Theme.spacing
            anchors.topMargin: Theme.spacing
            spacing: Theme.spacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingTight

                Text {
                    text: qsTr("AI SERVER")
                    font.pixelSize: Theme.fontTiny
                    font.weight: Font.DemiBold
                    color: Theme.textDisabled
                }
                Rectangle {
                    implicitWidth: 8; implicitHeight: 8; radius: 4
                    color: root.assistant.backendConnected ? Theme.success
                         : root.assistant.reachable         ? Theme.warning
                                                             : Theme.danger
                }
                Text {
                    text: root.assistant.statusText
                    font.pixelSize: Theme.fontTiny
                    color: root.assistant.backendConnected ? Theme.success
                         : root.assistant.reachable         ? Theme.warning
                                                             : Theme.danger
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Check now")
                    flat: true
                    onClicked: root.assistant.checkConnection()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.outline
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Theme.spacingTight
                rowSpacing: Theme.spacingTight

                Text {
                    text: qsTr("server URL")
                    font.pixelSize: Theme.fontTiny
                    color: Theme.textDisabled
                }
                TextField {
                    Layout.fillWidth: true
                    text: root.assistant.serverUrl
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSmall
                    onEditingFinished: root.assistant.serverUrl = text
                }

                Text {
                    text: qsTr("model")
                    font.pixelSize: Theme.fontTiny
                    color: Theme.textDisabled
                }
                ComboBox {
                    id: modelBox
                    Layout.fillWidth: true
                    model: root.assistant.availableModels
                    editable: false
                    enabled: root.assistant.availableModels.length > 0

                    /* availableModels can legitimately not contain
                       selectedModel yet -- nothing has connected since
                       launch, or the server's list changed. Show the saved
                       choice as selected without forcing it into the model
                       or resetting it. */
                    currentIndex: root.assistant.availableModels.indexOf(root.assistant.selectedModel)
                    displayText: currentIndex >= 0 ? currentText : root.assistant.selectedModel

                    onActivated: root.assistant.selectedModel = currentText
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.assistant.availableModels.length === 0
                text: qsTr("No models available — connect to a server with a reachable model backend.")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSmall
                color: Theme.textSecondary
            }

            Item { Layout.fillHeight: true }
        }
    }
}
