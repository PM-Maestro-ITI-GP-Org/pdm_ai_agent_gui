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

    property int currentView: 0   // 0 = ask, 1 = system map, 2 = lifecycle, 3 = settings

    AgentClient { id: assistant }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        spacing: Theme.spacing

        /* ---------------------------------------------------------------- */
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLoose

            ColumnLayout {
                /* The one flexible element in this row. Below it, the status
                   pill and the view switcher below both get a minimumWidth
                   pinned to their content, so a narrow window shrinks the
                   subtitle -- which can elide without losing meaning -- and
                   never the tab labels, which must stay readable and
                   clickable (this is what was truncating to "Syste…" /
                   "Lifecy…" / "Settin…" before: nothing here was exempt from
                   being shrunk, so the segmented control was squeezed along
                   with everything else). */
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2
                Text {
                    text: qsTr("AI Agent")
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Developer assistant for the PdM toolchain — read-only tool calls, no model side effects")
                    font.pixelSize: Theme.fontSmall
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                }
            }

            /* -------- live backend status --------
               Visible from every sub-view, not just Settings: whether the
               local model backend is actually there is exactly the kind of
               thing this tool should never make you go hunting for. Detail
               (server URL, model catalog) still lives in Settings; this is
               just "is it alive, and with what". */
            Rectangle {
                id: statusPill
                Layout.preferredHeight: Theme.controlHeight * 0.7
                Layout.minimumWidth: implicitWidth
                implicitWidth: statusRow.implicitWidth + Theme.spacing * 2
                radius: height / 2
                color: Theme.surfaceVariant
                border.width: 1
                border.color: Theme.outline

                readonly property color stateColor: assistant.backendConnected ? Theme.success
                                                   : assistant.reachable         ? Theme.warning
                                                                                 : Theme.danger
                readonly property bool live: assistant.backendConnected

                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingTight

                    Item {
                        id: dot
                        implicitWidth: 18
                        implicitHeight: 18

                        Rectangle {
                            id: halo
                            anchors.centerIn: parent
                            width: 8; height: 8
                            radius: 4
                            color: statusPill.stateColor
                            opacity: 0
                            visible: statusPill.live

                            ParallelAnimation {
                                running: statusPill.live
                                loops: Animation.Infinite
                                NumberAnimation { target: halo; property: "scale"; from: 1.0; to: 2.1; duration: 1400; easing.type: Easing.OutCubic }
                                NumberAnimation { target: halo; property: "opacity"; from: 0.45; to: 0.0; duration: 1400; easing.type: Easing.OutCubic }
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 8; height: 8
                            radius: 4
                            color: statusPill.stateColor
                        }
                    }

                    Text {
                        text: assistant.backendConnected
                              ? (assistant.backendName.length ? assistant.backendName : qsTr("connected"))
                                + (assistant.selectedModel.length ? " · " + assistant.selectedModel : "")
                              : assistant.statusText
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.Medium
                        color: Theme.textPrimary
                    }
                }
            }

            /* -------- the bootstrap button --------
               The one piece of the server this UI is allowed to own: when
               nothing answers at the configured URL, offer to launch it --
               once, detached, using the command setup.py wrote (Settings can
               edit it). Everything the server does after that first exec
               (build llama-server, download models, run backends) stays
               server-side per §6.1; this only crosses the chicken-and-egg
               gap of nobody having started uvicorn yet. With no command
               configured it stays visible but relabels -- clicking then
               lands on the status line explaining where to configure one,
               which beats a button that silently does nothing or one that
               vanishes taking its explanation with it. */
            Button {
                Layout.preferredHeight: Theme.controlHeight * 0.7
                visible: !assistant.reachable
                text: assistant.serverStartCommand.length ? qsTr("Start local AI")
                                                          : qsTr("Set up local AI…")
                onClicked: assistant.startServer()
            }

            /* -------- view switch, as a segmented control -------- */
            Rectangle {
                Layout.preferredHeight: Theme.controlHeight
                Layout.minimumWidth: implicitWidth
                implicitWidth: viewSwitch.implicitWidth + Theme.spacingTight * 2
                radius: Theme.radius
                color: Theme.surface
                border.width: 1
                border.color: Theme.outline

                TabBar {
                    id: viewSwitch
                    anchors.centerIn: parent
                    anchors.margins: Theme.spacingTight
                    currentIndex: root.currentView
                    onCurrentIndexChanged: root.currentView = currentIndex
                    background: Item {}

                    /* TabBar's own contentItem (a ListView) squeezes every
                       delegate to an equal share of the bar's width rather
                       than sizing each to its own label -- "Ask" fit inside
                       that share, "System Map"/"Lifecycle"/"Settings" did
                       not, and elided. `width: implicitWidth` re-asserts
                       each button's natural size, the same escape hatch
                       shell/qml/Main.qml already reaches for when the stock
                       TabBar layout disagrees with what a fixed set of
                       labeled buttons actually needs. */
                    TabButton { text: qsTr("Ask"); width: implicitWidth }
                    TabButton { text: qsTr("System Map"); width: implicitWidth }
                    TabButton { text: qsTr("Lifecycle"); width: implicitWidth }
                    TabButton { text: qsTr("Settings"); width: implicitWidth }
                }
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

            ChatView { assistant: assistant }
            SystemMapView {}
            LifecycleView {}
            SettingsView { assistant: assistant }
        }
    }
}
