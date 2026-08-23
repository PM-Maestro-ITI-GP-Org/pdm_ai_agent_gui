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

                /* -------- animated status dot --------
                   Same halo-pulse language as the pill in AgentPage's header
                   -- one signature status motif, not two. Pulses only while
                   the backend is actually serving; a reachable-but-not-
                   connected server holds a steady amber instead of implying
                   activity that isn't there. */
                Item {
                    id: dot
                    implicitWidth: 18
                    implicitHeight: 18

                    readonly property color stateColor: root.assistant.backendConnected ? Theme.success
                                                       : root.assistant.reachable         ? Theme.warning
                                                                                           : Theme.danger
                    readonly property bool live: root.assistant.backendConnected

                    Rectangle {
                        id: halo
                        anchors.centerIn: parent
                        width: 8; height: 8
                        radius: 4
                        color: dot.stateColor
                        opacity: 0
                        visible: dot.live

                        ParallelAnimation {
                            running: dot.live
                            loops: Animation.Infinite
                            NumberAnimation { target: halo; property: "scale"; from: 1.0; to: 2.1; duration: 1400; easing.type: Easing.OutCubic }
                            NumberAnimation { target: halo; property: "opacity"; from: 0.45; to: 0.0; duration: 1400; easing.type: Easing.OutCubic }
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 8; height: 8
                        radius: 4
                        color: dot.stateColor
                    }
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

            /* -------- what's actually loaded --------
               "Connected" alone doesn't say which backend or which model
               answered the last question; this does, from the same
               properties the header pill and the chat tab already read. */
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingLoose
                visible: root.assistant.reachable

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: qsTr("BACKEND")
                        font.pixelSize: Theme.fontTiny
                        color: Theme.textDisabled
                    }
                    Text {
                        text: root.assistant.backendName.length ? root.assistant.backendName : qsTr("—")
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }
                }
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: qsTr("ACTIVE MODEL")
                        font.pixelSize: Theme.fontTiny
                        color: Theme.textDisabled
                    }
                    Text {
                        text: root.assistant.selectedModel.length ? root.assistant.selectedModel : qsTr("none loaded")
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }
                }
                Item { Layout.fillWidth: true }
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

                /* Normally written by server/setup.py; editable here for the
                   "the server moved" case that shouldn't require rerunning a
                   wizard. */
                Text {
                    text: qsTr("start command")
                    font.pixelSize: Theme.fontTiny
                    color: Theme.textDisabled
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingTight

                    TextField {
                        id: startCommandField
                        Layout.fillWidth: true
                        text: root.assistant.serverStartCommand
                        placeholderText: qsTr("run server/setup.py to configure")
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSmall
                        onEditingFinished: root.assistant.serverStartCommand = text
                    }
                    Button {
                        flat: true
                        text: qsTr("Run")
                        enabled: startCommandField.text.length > 0 && !root.assistant.reachable
                        onClicked: root.assistant.startServer()
                    }
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
                    id: catalogRow
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Theme.spacingTight

                    readonly property bool isDownloading: root.assistant.downloadActive
                        && root.assistant.downloadingModelId === catalogRow.modelData.id
                    readonly property bool hasError: !root.assistant.downloadActive
                        && root.assistant.downloadingModelId === catalogRow.modelData.id
                        && root.assistant.downloadError.length > 0
                    readonly property bool showProgress: isDownloading || hasError

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingTight

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: catalogRow.modelData.label
                                font.pixelSize: Theme.fontSmall
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }
                            Text {
                                text: catalogRow.modelData.repo + " · " + root.formatBytes(catalogRow.modelData.sizeBytes)
                                font.pixelSize: Theme.fontTiny
                                color: Theme.textDisabled
                            }
                        }

                        Text {
                            visible: catalogRow.modelData.installed
                            text: qsTr("Installed")
                            font.pixelSize: Theme.fontTiny
                            font.weight: Font.DemiBold
                            color: Theme.success
                        }
                        Button {
                            visible: !catalogRow.modelData.installed
                            text: catalogRow.isDownloading ? qsTr("Downloading…") : qsTr("Download")
                            enabled: !catalogRow.modelData.installed && !root.assistant.downloadActive
                            onClicked: root.assistant.downloadModel(catalogRow.modelData.id)
                        }
                    }

                    /* -------- the download in progress --------
                       This is the moment users judge a local-model tool by:
                       make it feel like something substantial is actually
                       moving, not a thin default bar. Real bytes, a live
                       percent, and a sweep across the filled portion so it
                       reads as "working", not "stuck". */
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingTight
                        visible: catalogRow.showProgress

                        RowLayout {
                            Layout.fillWidth: true
                            visible: catalogRow.isDownloading
                            spacing: Theme.spacingTight

                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Downloading ") + catalogRow.modelData.label + qsTr("…")
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSmall
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }
                            Text {
                                text: root.assistant.downloadPercent.toFixed(0) + "%"
                                font.family: Theme.monoFamily
                                font.pixelSize: Theme.fontMedium
                                font.weight: Font.DemiBold
                                color: Theme.primary
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            visible: catalogRow.isDownloading
                            implicitHeight: 12
                            radius: Theme.radiusSmall
                            color: Theme.surfaceVariant
                            border.width: 1
                            border.color: Theme.outline

                            Rectangle {
                                id: fillBar
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.margins: 1
                                width: Math.max(0, (parent.width - 2) * (root.assistant.downloadPercent / 100))
                                radius: Theme.radiusSmall - 1
                                color: Theme.primary
                                clip: true

                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                                /* a soft highlight sweeping across the filled
                                   portion -- only while a download is active,
                                   never on an idle tab. */
                                Rectangle {
                                    id: sweep
                                    width: 40
                                    height: parent.height
                                    x: -40
                                    opacity: 0.3
                                    color: Theme.textOnAccent

                                    SequentialAnimation {
                                        running: catalogRow.isDownloading
                                        loops: Animation.Infinite
                                        NumberAnimation {
                                            target: sweep
                                            property: "x"
                                            from: -40
                                            to: fillBar.width + 40
                                            duration: 1100
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: catalogRow.isDownloading
                            text: root.formatBytes(root.assistant.downloadBytesDone) + " / "
                                  + root.formatBytes(root.assistant.downloadBytesTotal)
                            font.family: Theme.monoFamily
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
