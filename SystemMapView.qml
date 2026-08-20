import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
                     + "is flashed hardware the GUI reaches over USB serial, not a submodule.")
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
                    RepoCard {
                        /* Only `model` here, not the role names themselves --
                           a property declared with the same name as an
                           injected model role shadows it instead of reading
                           it. This is bug 1 in docs/STATUS.md
                           (ScenarioCard's `model` property shadowing the
                           Repeater's own), one property name over. */
                        required property var model

                        Layout.fillWidth: true
                        repoName: model.repoName
                        role: model.role
                        branch: model.branch
                        kind: model.kind
                        docPath: model.docPath
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
