import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import PdM.Core

/*
 * The repo graph: what docs/SCOPE.md §5 calls "the repo graph" half of A1.
 *
 * Deliberately just a hard-coded ListModel, not a filesystem scan or a git
 * subprocess -- see the note at the bottom of this file for why, and what a
 * later step would need to change to make it live.
 *
 * Data taken from PdM-Maestro_gui/CLAUDE.md's own repo table, which is the
 * project's own map and the source this view exists to make navigable rather
 * than duplicate. If this list and CLAUDE.md ever disagree, CLAUDE.md is
 * right -- the same rule the rest of this project already follows.
 *
 * Rendered as a small architecture diagram rather than a plain list: a
 * spine running top to bottom, the hub as its root node, a solid connector
 * out to each submodule, and a dashed one out to the firmware entry -- dashed
 * specifically because it is not a submodule, reached over USB serial
 * instead of pulled into the build. The line style carries that distinction,
 * not just the badge text.
 */
Item {
    ListModel {
        id: repos

        ListElement {
            repoName: "PdM-Maestro_gui"
            role: "The shell: ApplicationWindow, TabBar, StackLayout, and the pin for every submodule below. This repo."
            branch: "main"
            kind: "hub"
            docPath: "/home/zee/ITI_Files/GP/PdM_Maestro_devApp/CLAUDE.md"
        }
        ListElement {
            repoName: "pdm_app_core"
            role: "Shared Theme, MessageBus, AppRegistry, BrokerSettings, SafetyStop. What every tab has in common."
            branch: "main"
            kind: "submodule"
            docPath: "/home/zee/ITI_Files/GP/PdM_Maestro_devApp/core/README.md"
        }
        ListElement {
            repoName: "pdm_motor_control_gui"
            role: "Motor Control tab. Runs the scripted A–J profiles on the ESP32 rig, records custom hand sweeps."
            branch: "main"
            kind: "submodule"
            docPath: "/home/zee/ITI_Files/GP/PdM_Maestro_devApp/apps/motor_control/README.md"
        }
        ListElement {
            repoName: "pdm_mlops_gui"
            role: "ML/Ops tab. Reads the training pipeline's own gate verdict; re-implements none of the thresholds."
            branch: "main"
            kind: "submodule"
            docPath: "/home/zee/ITI_Files/GP/PdM_Maestro_devApp/apps/mlops/README.md"
        }
        ListElement {
            repoName: "motor_recorder_gui"
            role: "Data Collection tab. Ported, not new — was its own app before Maestro existed."
            branch: "feat/maestro-integration"
            kind: "submodule"
            docPath: "/home/zee/ITI_Files/GP/PdM_Maestro_devApp/apps/data_collection/README.md"
        }
        ListElement {
            repoName: "ota_update_gui"
            role: "OTA Update tab. Ported, not new. Can kill hypervisor guests and push updates over MQTT."
            branch: "feat/maestro-integration"
            kind: "submodule"
            docPath: "/home/zee/ITI_Files/GP/PdM_Maestro_devApp/apps/ota/README.md"
        }
        ListElement {
            repoName: "pdm_ai_agent_gui"
            role: "AI Agent tab. This app — a developer assistant, not the driver-facing voice assistant."
            branch: "main"
            kind: "submodule"
            docPath: "/home/zee/ITI_Files/GP/PdM_Maestro_devApp/apps/agent/docs/SCOPE.md"
        }
        ListElement {
            repoName: "motor_control_node"
            role: "The ESP32 rig firmware + protocol docs (folder name esp_dac). Not a Maestro submodule — the GUI talks to it over USB serial."
            branch: "feat/estop-2500ms"
            kind: "firmware"
            docPath: "/home/zee/ITI_Files/GP/dataCollection/esp_dac/README.md"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingTight

        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacingTight
            text: qsTr("Eight repositories. Seven are submodules of the hub above; the firmware "
                     + "is flashed hardware the GUI reaches over USB serial — drawn with a dashed "
                     + "connector below, not a solid one, for exactly that reason.")
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSmall
            color: Theme.textSecondary
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: Theme.spacingTight

                Repeater {
                    model: repos

                    delegate: RowLayout {
                        id: rowDelegate

                        /* Declared on the delegate's own root, not read from
                           outer scope -- this is the fix for the shadowing
                           bug documented in docs/STATUS.md (bug 1) and it has
                           recurred once already in this repo. */
                        required property var model
                        required property int index

                        Layout.fillWidth: true
                        spacing: 0

                        Item {
                            id: rail

                            readonly property var entry: rowDelegate.model
                            readonly property bool isHub: rail.entry.kind === "hub"
                            readonly property bool isFirmware: rail.entry.kind === "firmware"
                            readonly property bool isFirst: rowDelegate.index === 0
                            readonly property bool isLast: rowDelegate.index === repos.count - 1

                            Layout.preferredWidth: Theme.spacingLoose
                            Layout.fillHeight: true

                            /* spine, above and below the node -- split in two
                               so the line can stop cleanly at the first and
                               last rows instead of dangling past the ends. */
                            Rectangle {
                                visible: !rail.isFirst
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 2
                                height: parent.height / 2
                                color: Theme.outline
                            }
                            Rectangle {
                                visible: !rail.isLast
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 2
                                height: parent.height / 2
                                color: Theme.outline
                            }

                            /* solid connector from the spine into the card */
                            Rectangle {
                                visible: !rail.isHub && !rail.isFirmware
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.horizontalCenter
                                anchors.right: parent.right
                                height: 2
                                color: Theme.outline
                            }

                            /* dashed connector for the firmware entry --
                               the line style itself carries "not a submodule",
                               not just the badge text on the card. */
                            Shape {
                                id: dashConnector
                                visible: !rail.isHub && rail.isFirmware
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.horizontalCenter
                                anchors.right: parent.right
                                height: 2

                                ShapePath {
                                    strokeColor: Theme.textSecondary
                                    strokeWidth: 2
                                    strokeStyle: ShapePath.DashLine
                                    dashPattern: [2, 2]
                                    fillColor: "transparent"
                                    startX: 0
                                    startY: 1
                                    PathLine { x: dashConnector.width; y: 1 }
                                }
                            }

                            /* the node itself */
                            Rectangle {
                                anchors.centerIn: parent
                                width: rail.isHub ? 12 : 9
                                height: width
                                radius: width / 2
                                color: rail.isFirmware ? Theme.textSecondary : Theme.primary
                                border.width: rail.isHub ? 0 : 2
                                border.color: Theme.surface
                            }
                        }

                        RepoCard {
                            Layout.fillWidth: true
                            repoName: rowDelegate.model.repoName
                            role: rowDelegate.model.role
                            branch: rowDelegate.model.branch
                            kind: rowDelegate.model.kind
                            docPath: rowDelegate.model.docPath
                        }
                    }
                }
            }
        }
    }
}

/*
 * Why hard-coded rather than read live (branch, whether the pin matches HEAD,
 * whether the checkout is dirty):
 *
 * 1. It needs `git`, run as a subprocess -- and every existing app in this
 *    toolchain that shells out to a process does it off the GUI thread (see
 *    RigFetcher and the MQTT-connect fix in docs/STATUS.md). Doing it
 *    directly on the GUI thread here would repeat exactly the bug rule 8 of
 *    INTEGRATION_CONTRACT.md exists to prevent.
 * 2. docs/SCOPE.md asked for small steps. A static, correct-today map is a
 *    complete, useful, checkable increment; a live one is a second increment
 *    with a real design question behind it (poll on a timer? on tab focus?
 *    background thread, like RigFetcher's checkSession()?) that deserves its
 *    own decision rather than being bundled in here by default.
 */
