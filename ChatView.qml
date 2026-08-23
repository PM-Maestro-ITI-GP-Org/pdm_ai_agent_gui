import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import PdM.Core

/*
 * The chat tab (A2a/A2b, docs/SCOPE.md §6/§7): a running transcript, each
 * question grounded and cited on its own, with the server given the prior
 * turns as conversational context (docs/SCOPE.md's A2b addendum) so a
 * follow-up like "and how do I undo that" means something.
 *
 * The server call is not streamed (SCOPE.md §6.1 has no token stream on the
 * wire), so the "it's thinking" and "it's typing" feel is built here,
 * client-side, against the one answer string that arrives at the end.
 */
Item {
    id: root

    required property var assistant

    /* Completed turns, oldest first: {question, answer, error, sources,
       grounded, citationChecked, citationSupported, bestSupported, navigate}.
       `navigate` is the {tab, section} a `navigate_to` tool call returned,
       or null. This is the transcript; `assistant.chat*` only ever reflects
       the single most recent exchange, so each turn snapshots what it needs
       out of those properties before the next question overwrites them. */
    property var transcript: []

    /* Which transcript index is still being typewriter-revealed, -1 if none.
       Only that one delegate reads live `shownChars`; every earlier turn
       just renders its full answer -- there is nothing left to animate. */
    property int liveIndex: -1

    /* Which transcript index is currently showing its "take me there?"
       banner, -1 if none. Set only after `navigateDelay` fires -- see that
       Timer below for why this isn't instant. */
    property int navigateSuggestionIndex: -1

    /* The question in flight while `assistant.chatBusy` is true. Captured at
       submit time, before the input clears, so the completed-turn object
       built in `onChatStateChanged` below has something to attach the
       answer to -- `assistant` itself never exposes the question it was
       asked, only the answer. */
    property string pendingQuestion: ""

    readonly property bool hasContent: transcript.length > 0 || assistant.chatBusy

    /* A blank input box gives no sense of what's actually answerable from
       this corpus. Grouped by which part of the toolchain they're about --
       each question is a case this tab's own docs (SCOPE.md §6.6, §7,
       RIG_ACCESS.md, ARCHITECTURE.md) were written to explain, not an
       invented example. Not a live feature list; a starting point. */
    readonly property var hintCategories: [
        {
            category: qsTr("System"),
            questions: [
                qsTr("What tabs does PdM Maestro have?"),
                qsTr("How do I add a sixth tab?"),
            ],
        },
        {
            category: qsTr("Motor Rig"),
            questions: [
                qsTr("Why can't SSH keys reach the rig?"),
                qsTr("What makes the emergency stop safe to rely on?"),
            ],
        },
        {
            category: qsTr("ML / Data"),
            questions: [
                qsTr("What breaks if my data is audio instead of a time series?"),
                qsTr("Why isn't ML/Ops built against the AI repo directly?"),
            ],
        },
    ]

    function useHint(text) {
        input.text = text;
        input.forceActiveFocus();
    }

    /* The server's own conversational memory: its `/chat` only ever sees one
       message plus whatever `history` this sends alongside it (docs/SCOPE.md's
       A2b addendum) -- retrieval reruns fresh each turn, but the model gets
       to see what was actually asked and answered before, which is what a
       follow-up like "and how do I undo that" needs to mean anything. */
    function historyForServer() {
        const turns = [];
        for (const turn of root.transcript) {
            turns.push({ role: "user", content: turn.question });
            if (turn.answer.length > 0)
                turns.push({ role: "assistant", content: turn.answer });
        }
        return turns;
    }

    function submit() {
        const text = input.text.trim();
        if (text.length === 0 || root.assistant.chatBusy)
            return;
        root.pendingQuestion = text;
        input.text = "";
        root.assistant.askQuestion(text, root.historyForServer());
        Qt.callLater(() => { transcriptFlickable.contentY = 0; });
    }

    /* Newest first: the transcript itself stays chronological (indices feed
       `historyForServer()`, `liveIndex`, `navigateSuggestionIndex`), but the
       Repeater below renders this reversed view instead so the latest answer
       lands at the top, right under the input, with no scrolling needed. */
    readonly property var reversedTranscript: {
        const out = [];
        for (let i = root.transcript.length - 1; i >= 0; i--)
            out.push({ i: i, t: root.transcript[i] });
        return out;
    }

    function acceptNavigate(index) {
        const turn = root.transcript[index];
        if (turn && turn.navigate)
            MessageBus.publish("agent.navigate", turn.navigate);
        if (root.navigateSuggestionIndex === index)
            root.navigateSuggestionIndex = -1;
    }

    function dismissNavigate(index) {
        if (root.navigateSuggestionIndex === index)
            root.navigateSuggestionIndex = -1;
    }

    Connections {
        target: root.assistant
        function onChatStateChanged() {
            if (root.assistant.chatBusy)
                return;
            if (root.assistant.chatAnswer.length === 0 && root.assistant.chatError.length === 0)
                return;

            let navigate = null;
            for (const call of root.assistant.chatToolCalls) {
                if (call.name === "navigate_to" && call.result && call.result.navigate)
                    navigate = call.result.navigate;
            }

            root.transcript = root.transcript.concat([{
                question: root.pendingQuestion,
                answer: root.assistant.chatAnswer,
                error: root.assistant.chatError,
                sources: root.assistant.chatSources,
                grounded: root.assistant.chatGrounded,
                citationChecked: root.assistant.chatCitationChecked,
                citationSupported: root.assistant.chatCitationSupported,
                bestSupported: root.assistant.chatBestSupported,
                navigate: navigate,
            }]);
            root.pendingQuestion = "";

            if (root.assistant.chatAnswer.length > 0) {
                root.liveIndex = root.transcript.length - 1;
                typewriter.shownChars = 0;
                typewriter.start();
            }

            Qt.callLater(() => { transcriptFlickable.contentY = 0; });
        }
    }

    /*
     * "Take me there" is a delayed suggestion, not an instant jump -- asked
     * to explain something, the agent used to publish `agent.navigate` the
     * moment the tool call came back, before a single word of the answer had
     * even rendered, and the tab underneath the reader would just switch out
     * from under the sentence explaining it. Now the answer types out in
     * full first, waits `navigateDelay`'s interval past that so it reads as
     * "and now let me show you" rather than "here, deal with it," and only
     * then offers the jump -- the user still clicks it themselves.
     */
    Timer {
        id: navigateDelay
        interval: 1800
        repeat: false
        onTriggered: {
            if (root.liveIndex >= 0 && root.liveIndex < root.transcript.length
                    && root.transcript[root.liveIndex].navigate)
                root.navigateSuggestionIndex = root.liveIndex;
        }
    }

    Timer {
        id: typewriter
        property int shownChars: 0
        interval: 24
        repeat: true
        running: false
        onTriggered: {
            shownChars += 3;
            const live = (root.liveIndex >= 0 && root.liveIndex < root.transcript.length)
                       ? root.transcript[root.liveIndex] : null;
            if (!live || shownChars >= live.answer.length) {
                stop();
                if (live && live.navigate)
                    navigateDelay.restart();
            }
        }
    }

    Flickable {
        id: transcriptFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, centerColumn.implicitHeight + Theme.spacingLoose * 2)
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Behavior on contentY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: centerColumn
            width: Math.min(parent.width - Theme.spacingLoose * 2, 720)
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.hasContent
               ? Theme.spacingLoose
               : Math.max(Theme.spacingLoose, (transcriptFlickable.height - implicitHeight) / 2)
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

                /* Plain Material TextField, no custom background or manual
                   placeholder overlay -- see docs/SCOPE.md's UI notes for
                   why: a hand-rolled TextArea background kept surfacing new
                   rendering issues instead of settling. */
                TextField {
                    id: input
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.controlHeight
                    Material.containerStyle: Material.Outlined
                    /* Generic, not one of the hint chips' own example
                       questions verbatim -- it used to repeat the ML/Data
                       category's "What breaks if my data is audio..."
                       word-for-word while that exact chip sat directly
                       below it, which read as a duplicate rather than two
                       different things (a ghost hint and a clickable
                       example). */
                    placeholderText: root.transcript.length > 0
                                      ? qsTr("Ask a follow-up…")
                                      : qsTr("Ask a question about the toolchain…")
                    readOnly: root.assistant.chatBusy
                    opacity: root.assistant.chatBusy ? 0.6 : 1.0
                    selectByMouse: true
                    onAccepted: root.submit()
                }

                Button {
                    text: qsTr("Ask")
                    highlighted: true
                    enabled: !root.assistant.chatBusy && input.text.trim().length > 0
                    Layout.preferredHeight: Theme.controlHeight
                    onClicked: root.submit()
                }
            }

            /* -------- example questions, by category --------
               Only before the first question -- once a transcript exists
               these would just be clutter above it. Same chip visuals as
               the source citations further down: one design system, not two. */
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacingTight
                visible: root.transcript.length === 0 && !root.assistant.chatBusy
                spacing: Theme.spacingTight

                Repeater {
                    model: root.hintCategories

                    delegate: ColumnLayout {
                        id: categoryBlock
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: categoryBlock.modelData.category
                            font.pixelSize: Theme.fontTiny
                            font.weight: Font.DemiBold
                            font.capitalization: Font.AllUppercase
                            color: Theme.textDisabled
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingTight

                            Repeater {
                                model: categoryBlock.modelData.questions
                                delegate: Rectangle {
                                    id: hintChip
                                    required property string modelData

                                    implicitWidth: hintLabel.implicitWidth + Theme.spacing * 2.5
                                    implicitHeight: hintLabel.implicitHeight + Theme.spacing * 1.5
                                    radius: Theme.radius
                                    color: hover.hovered ? Theme.primarySoft : Theme.surface
                                    border.width: 1
                                    border.color: hover.hovered ? Theme.primary : Theme.outline

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        id: hintLabel
                                        anchors.centerIn: parent
                                        text: hintChip.modelData
                                        font.pixelSize: Theme.fontSmall
                                        color: hover.hovered ? Theme.primary : Theme.textSecondary
                                    }

                                    HoverHandler { id: hover }
                                    TapHandler { onTapped: root.useHint(hintChip.modelData) }
                                }
                            }
                        }
                    }
                }
            }

            /* -------- the in-flight question --------
               Not yet a transcript entry -- it becomes one the moment
               `onChatStateChanged` above sees the answer land. Placed above
               the transcript, not below: newest-first means "what's
               happening right now" belongs at the top too, right where the
               completed turn it becomes will appear next. */
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing
                visible: root.assistant.chatBusy
                spacing: Theme.spacingTight

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight
                    text: root.pendingQuestion
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.Medium
                    color: Theme.textSecondary
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
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
                    text: qsTr("thinking…")
                    font.pixelSize: Theme.fontTiny
                    color: Theme.textDisabled
                }
            }

            /* -------- the transcript, newest first -------- */
            Repeater {
                model: root.reversedTranscript

                delegate: ColumnLayout {
                    id: turnBlock
                    required property var modelData
                    readonly property var turn: modelData.t
                    readonly property int index: modelData.i

                    readonly property bool isLive: turnBlock.index === root.liveIndex
                    readonly property int revealedChars: turnBlock.isLive
                        ? Math.min(typewriter.shownChars, turnBlock.turn.answer.length)
                        : turnBlock.turn.answer.length
                    readonly property bool fullyRevealed:
                        turnBlock.revealedChars >= turnBlock.turn.answer.length

                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacing
                    spacing: Theme.spacingTight

                    /* -------- the question, as asked -------- */
                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        text: turnBlock.turn.question
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignRight
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                    }

                    /* -------- the answer -------- */
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: answerColumn.implicitHeight + Theme.spacing * 2
                        color: Theme.surface
                        border.color: Theme.outline
                        border.width: 1
                        radius: Theme.radius

                        ColumnLayout {
                            id: answerColumn
                            anchors.fill: parent
                            anchors.margins: Theme.spacing
                            spacing: Theme.spacing

                            Text {
                                Layout.fillWidth: true
                                visible: turnBlock.turn.answer.length > 0
                                text: turnBlock.turn.answer.substring(0, turnBlock.revealedChars)
                                /* The model writes real Markdown -- **bold**,
                                   lists, code spans. Qt's own Markdown support
                                   (textFormat, not a dependency) renders it;
                                   the one cost is a mid-reveal unclosed `**`
                                   can look odd for a frame or two on the live
                                   turn, self-correcting once revealed. */
                                textFormat: Text.MarkdownText
                                wrapMode: Text.WordWrap
                                font.pixelSize: Theme.fontBody
                                color: Theme.textPrimary
                            }

                            /* -------- sources --------
                               Held back until this turn's answer has finished
                               revealing -- appearing mid-reveal would put the
                               citations on screen before the sentence that
                               cites them. Already-settled turns above this
                               one are always fully revealed, so this is only
                               ever a wait on the live turn. */
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingTight
                                visible: turnBlock.turn.sources.length > 0 && turnBlock.fullyRevealed

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: Theme.outline
                                }

                                /* Four states, and they are genuinely different
                                   things. An answer that cited nothing, an
                                   answer whose citation does not match what it
                                   actually used, and an answer that checked out
                                   are three separate outcomes -- collapsing them
                                   into "grounded: yes/no" is what let a wrong
                                   citation read as a right one. */
                                Text {
                                    readonly property bool cited: turnBlock.turn.grounded
                                    readonly property bool checked: turnBlock.turn.citationChecked
                                    readonly property bool supported: turnBlock.turn.citationSupported

                                    text: !cited ? qsTr("Sources — the answer cited none of them")
                                         : !checked ? qsTr("Sources")
                                         : supported ? qsTr("Sources — citation checked")
                                         : qsTr("Sources — the answer does not match what it cited")
                                    font.pixelSize: Theme.fontTiny
                                    font.weight: Font.DemiBold
                                    color: !cited ? Theme.warning
                                         : !checked ? Theme.textSecondary
                                         : supported ? Theme.success
                                         : Theme.danger
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingTight

                                    Repeater {
                                        model: turnBlock.turn.sources
                                        delegate: Rectangle {
                                            /* `required property var modelData`, not a bare
                                               `modelData` reference: docs/STATUS.md bug 1 was a
                                               delegate quietly reading an outer property of the
                                               same name, and it repeated once already in this
                                               repo (SCOPE.md §10, A1). Doubly relevant here, one
                                               level deeper, with the outer delegate's own
                                               `modelData` shadowed the same way. */
                                            required property var modelData

                                            readonly property bool mismatched:
                                                turnBlock.turn.citationChecked
                                                && !turnBlock.turn.citationSupported
                                                && modelData.n === turnBlock.turn.bestSupported

                                            implicitWidth: chip.implicitWidth + Theme.spacing
                                            implicitHeight: chip.implicitHeight + Theme.spacingTight
                                            radius: Theme.radiusSmall
                                            color: mismatched ? Theme.dangerSoft
                                                 : modelData.cited ? Theme.primarySoft
                                                 : Theme.neutralSoft
                                            border.width: 1
                                            border.color: mismatched ? Theme.danger
                                                        : modelData.cited ? Theme.primary
                                                        : Theme.outline
                                            opacity: (modelData.cited || mismatched) ? 1.0 : 0.7

                                            RowLayout {
                                                id: chip
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Text {
                                                    text: "[" + modelData.n + "]"
                                                    font.pixelSize: Theme.fontTiny
                                                    font.weight: Font.DemiBold
                                                    color: modelData.cited ? Theme.primary : Theme.textDisabled
                                                }
                                                Text {
                                                    text: modelData.citation
                                                    font.pixelSize: Theme.fontTiny
                                                    color: Theme.textSecondary
                                                    elide: Text.ElideMiddle
                                                    Layout.maximumWidth: 420
                                                }
                                            }

                                            ToolTip.visible: sourceHover.hovered
                                            ToolTip.text: qsTr("%1 — similarity %2%3")
                                                .arg(modelData.path)
                                                .arg(Math.round(modelData.score * 100))
                                                .arg(mismatched
                                                     ? qsTr(" — this is what the answer actually used")
                                                     : modelData.cited ? "" : qsTr(", not cited"))

                                            HoverHandler { id: sourceHover }
                                        }
                                    }
                                }
                            }

                            /* -------- take me there? --------
                               See the `navigateDelay` Timer above for why
                               this waits instead of just happening. A click
                               publishes on MessageBus (docs/SCOPE.md §6.2);
                               nothing here touches the bus until then. */
                            RowLayout {
                                Layout.fillWidth: true
                                visible: turnBlock.index === root.navigateSuggestionIndex
                                spacing: Theme.spacingTight

                                Text {
                                    Layout.fillWidth: true
                                    text: turnBlock.turn.navigate
                                          ? qsTr("Want me to take you to the %1 tab?")
                                                .arg(turnBlock.turn.navigate.tab)
                                          : ""
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: Theme.fontSmall
                                    color: Theme.textSecondary
                                }
                                Button {
                                    text: qsTr("Take me there")
                                    highlighted: true
                                    onClicked: root.acceptNavigate(turnBlock.index)
                                }
                                ToolButton {
                                    text: qsTr("Not now")
                                    onClicked: root.dismissNavigate(turnBlock.index)
                                }
                            }

                            /* -------- error -------- */
                            Text {
                                Layout.fillWidth: true
                                visible: turnBlock.turn.error.length > 0
                                text: turnBlock.turn.error
                                wrapMode: Text.WordWrap
                                font.pixelSize: Theme.fontSmall
                                color: Theme.danger
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: Theme.spacingLoose }
        }
    }
}
