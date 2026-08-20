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

    function formatBytes(bytes) {
        if (!bytes || bytes <= 0)
            return qsTr("0 B");
        const units = ["B", "KB", "MB", "GB", "TB"];
        var value = bytes;
        var unit = 0;
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024;
            unit++;
        }
        return (unit === 0 ? value.toFixed(0) : value.toFixed(1)) + " " + units[unit];
    }

    Component.onCompleted: assistant.refreshCatalog()

    Connections {
        target: root.assistant
        function onDownloadStateChanged() {
            if (root.assistant.downloadDone)
                root.assistant.refreshCatalog();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing

    Rectangle {
        Layout.fillWidth: true
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
                    text: qsTr("Model in use")
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
        }
    }

    Rectangle {
        Layout.fillWidth: true
        color: Theme.surface
        border.color: Theme.outline
        border.width: 1
        radius: Theme.radius
        implicitHeight: downloadContent.implicitHeight + Theme.spacing * 2

        ColumnLayout {
            id: downloadContent
            anchors.fill: parent
            anchors.margins: Theme.spacing
            spacing: Theme.spacing

            Text {
                text: qsTr("DOWNLOAD A MODEL")
                font.pixelSize: Theme.fontTiny
                font.weight: Font.DemiBold
                color: Theme.textDisabled
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.outline
            }

            Text {
                Layout.fillWidth: true
                visible: root.assistant.modelCatalog.length === 0
                text: qsTr("No catalog yet — waiting on the server.")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSmall
                color: Theme.textSecondary
            }

            Repeater {
                model: root.assistant.modelCatalog

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingTight

                    readonly property bool isDownloading: root.assistant.downloadActive
                        && root.assistant.downloadingModelId === modelData.id
                    readonly property bool hasError: !root.assistant.downloadActive
                        && root.assistant.downloadingModelId === modelData.id
                        && root.assistant.downloadError.length > 0
                    readonly property bool showProgress: isDownloading || hasError

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingTight

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.label
                                font.pixelSize: Theme.fontSmall
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }
                            Text {
                                text: modelData.repo + " · " + root.formatBytes(modelData.sizeBytes)
                                font.pixelSize: Theme.fontTiny
                                color: Theme.textDisabled
                            }
                        }

                        Text {
                            visible: modelData.installed
                            text: qsTr("Installed")
                            font.pixelSize: Theme.fontTiny
                            font.weight: Font.DemiBold
                            color: Theme.success
                        }
                        Button {
                            visible: !modelData.installed
                            text: isDownloading ? qsTr("Downloading…") : qsTr("Download")
                            enabled: !modelData.installed && !root.assistant.downloadActive
                            onClicked: root.assistant.downloadModel(modelData.id)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: showProgress

                        ProgressBar {
                            Layout.fillWidth: true
                            visible: isDownloading
                            from: 0
                            to: 100
                            value: root.assistant.downloadPercent

                            background: Rectangle {
                                implicitHeight: 8
                                radius: Theme.radiusSmall
                                color: Theme.surfaceVariant
                            }
                            contentItem: Item {
                                implicitHeight: 8
                                Rectangle {
                                    width: parent.width * (root.assistant.downloadPercent / 100)
                                    height: parent.height
                                    radius: Theme.radiusSmall
                                    color: Theme.primary
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: isDownloading
                            text: modelData.label + " — "
                                  + root.formatBytes(root.assistant.downloadBytesDone) + " / "
                                  + root.formatBytes(root.assistant.downloadBytesTotal)
                                  + " (" + root.assistant.downloadPercent.toFixed(0) + "%)"
                            font.pixelSize: Theme.fontTiny
                            color: Theme.textSecondary
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.assistant.downloadError.length > 0
                            text: root.assistant.downloadError
                            wrapMode: Text.WordWrap
                            font.pixelSize: Theme.fontTiny
                            color: Theme.danger
                        }
                    }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }
    }
}
