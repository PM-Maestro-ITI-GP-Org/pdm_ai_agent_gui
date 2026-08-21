import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PdM.Core

/*
 * The chat tab (A2a, docs/SCOPE.md §6/§7): a single question in, one grounded
 * answer out. No transcript yet -- one question at a time is the deliberate
 * scope, not an oversight.
 *
 * The server call is not streamed (SCOPE.md §6.1 has no token stream on the
 * wire), so the "it's thinking" and "it's typing" feel is built here,
 * client-side, against the one answer string that arrives at the end.
 */
Item {
    id: root

    required property var assistant

    readonly property int revealedCount: Math.min(typewriter.shownChars, fullAnswer.length)
    readonly property string fullAnswer: root.assistant.chatAnswer

    function submit() {
        const text = input.text.trim();
        if (text.length === 0 || root.assistant.chatBusy)
            return;
        typewriter.stop();
        typewriter.shownChars = 0;
        root.assistant.askQuestion(text);
    }

    Connections {
        target: root.assistant
        function onChatStateChanged() {
            if (!root.assistant.chatBusy && root.assistant.chatAnswer.length > 0) {
                typewriter.shownChars = 0;
                typewriter.start();
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, centerColumn.implicitHeight + Theme.spacingLoose * 2)
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: centerColumn
            width: Math.min(parent.width - Theme.spacingLoose * 2, 720)
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.spacingLoose
            spacing: Theme.spacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: qsTr("Ask the agent")
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
                Text {
                    text: qsTr("Grounded in this toolchain's own docs — answers cite where they came from.")
                    font.pixelSize: Theme.fontSmall
                    color: Theme.textSecondary
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingTight

                TextArea {
                    id: input
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(implicitHeight, 96)
                    wrapMode: TextArea.Wrap
                    /* readOnly, not enabled: false -- toggling `enabled` off and back
                       on left Material's TextArea painting the placeholder behind the
                       real text permanently once re-enabled. readOnly blocks editing
                       without going through that path. */
                    readOnly: root.assistant.chatBusy
                    opacity: root.assistant.chatBusy ? 0.6 : 1.0
                    selectByMouse: true

                    /* Not TextArea.placeholderText -- this Qt/Material build paints
                       the built-in placeholder behind real text instead of hiding
                       it once there's content (reproduces in a bare TextArea, no
                       app code involved). A manually-hidden Text sidesteps it. */
                    Text {
                        anchors.fill: parent
                        anchors.margins: 6
                        text: qsTr("What breaks if my data is audio instead of a time series?")
                        color: Theme.textDisabled
                        visible: input.text.length === 0
                        wrapMode: Text.Wrap
                    }

                    background: Rectangle {
                        color: Theme.surface
                        border.color: input.activeFocus ? Theme.primary : Theme.outline
                        border.width: 1
                        radius: Theme.radius
                    }

                    Keys.onPressed: (event) => {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            && !(event.modifiers & Qt.ShiftModifier)) {
                            event.accepted = true;
                            root.submit();
                        }
                    }
                }

                Button {
                    text: qsTr("Ask")
                    highlighted: true
                    enabled: !root.assistant.chatBusy && input.text.trim().length > 0
                    Layout.preferredHeight: Theme.controlHeight
                    onClicked: root.submit()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: answerColumn.implicitHeight + Theme.spacing * 2
                visible: root.assistant.chatBusy
                         || root.assistant.chatAnswer.length > 0
                         || root.assistant.chatError.length > 0
                color: Theme.surface
                border.color: Theme.outline
                border.width: 1
                radius: Theme.radius

                ColumnLayout {
                    id: answerColumn
                    anchors.fill: parent
                    anchors.margins: Theme.spacing
                    spacing: Theme.spacing

                    /* -------- thinking -------- */
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.assistant.chatBusy
                        spacing: Theme.spacingTight

                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                required property int index
                                implicitWidth: 10
                                implicitHeight: 10
                                radius: 5
                                color: Theme.primary

                                SequentialAnimation on opacity {
                                    running: root.assistant.chatBusy
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: index * 150 }
                                    NumberAnimation { from: 0.25; to: 1.0; duration: 350; easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: 1.0; to: 0.25; duration: 350; easing.type: Easing.InOutQuad }
                                    PauseAnimation { duration: (2 - index) * 150 }
                                }
                                SequentialAnimation on scale {
                                    running: root.assistant.chatBusy
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: index * 150 }
                                    NumberAnimation { from: 0.7; to: 1.15; duration: 350; easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: 1.15; to: 0.7; duration: 350; easing.type: Easing.InOutQuad }
                                    PauseAnimation { duration: (2 - index) * 150 }
                                }
                            }
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.assistant.chatBusy
                        text: qsTr("thinking…")
                        font.pixelSize: Theme.fontTiny
                        color: Theme.textDisabled
                    }

                    /* -------- answer, typewriter-revealed -------- */
                    Text {
                        Layout.fillWidth: true
                        visible: !root.assistant.chatBusy && root.assistant.chatAnswer.length > 0
                        text: root.fullAnswer.substring(0, root.revealedCount)
                        wrapMode: Text.WordWrap
                        font.pixelSize: Theme.fontBody
                        color: Theme.textPrimary

                        Timer {
                            id: typewriter
                            property int shownChars: 0
                            interval: 24
                            repeat: true
                            running: false
                            onTriggered: {
                                shownChars += 3;
                                if (shownChars >= root.fullAnswer.length)
                                    stop();
                            }
                        }
                    }

                    /* -------- error -------- */
                    Text {
                        Layout.fillWidth: true
                        visible: !root.assistant.chatBusy && root.assistant.chatError.length > 0
                        text: root.assistant.chatError
                        wrapMode: Text.WordWrap
                        font.pixelSize: Theme.fontSmall
                        color: Theme.danger
                    }
                }
            }

            Item { Layout.preferredHeight: Theme.spacingLoose }
        }
    }
}
