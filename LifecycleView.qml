import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import PdM.Core

/*
 * The ML development lifecycle: the other half of A1 (docs/SCOPE.md §5).
 *
 * Read directly from AI/host_pipeline/README.md on 2026-08-20. That repo is
 * being actively reworked by someone else as of the same date -- see
 * docs/SCOPE.md §5 and §9, and docs/STATUS.md in PdM-Maestro_gui -- so this
 * view is deliberately labelled provisional rather than presented as settled.
 * It is safe to *show*: nothing here edits the AI repo, and every stage links
 * back to the real document rather than asserting anything beyond what that
 * document said on the date it was read. It is not safe to treat as current
 * without re-checking once the rework lands.
 *
 * Rendered as a pipeline diagram: a numbered spine running top to bottom with
 * an arrow between each stage showing the direction data flows, not a plain
 * list. The gate stage's node is drawn as a diamond rather than a circle --
 * it is a checkpoint, not a processing step, and the shape says so before the
 * "path uncertain" badge on its card does.
 */
Item {
    ListModel {
        id: stages

        ListElement {
            stageName: "data_building.ipynb"
            role: "Raw motor CSV → feature table."
            writes: "data/features/features_<task>.csv"
            status: "stage"
            docPath: "/home/zee/ITI_Files/GP/ai/AI/docs/host_pipeline/data_building.md"
        }
        ListElement {
            stageName: "anomaly.ipynb"
            role: "Normal vs. abnormal — Isolation Forest + Mahalanobis distance."
            writes: "model/anomaly/, config/anomaly/"
            status: "stage"
            docPath: "/home/zee/ITI_Files/GP/ai/AI/docs/host_pipeline/anomaly.md"
        }
        ListElement {
            stageName: "classification.ipynb"
            role: "Normal / mechanical / electrical fault — 1D CNN."
            writes: "model/classification/, config/classification/"
            status: "stage"
            docPath: "/home/zee/ITI_Files/GP/ai/AI/docs/host_pipeline/classification.md"
        }
        ListElement {
            stageName: "rul.ipynb"
            role: "Health score + remaining useful life — ridge regression + isotonic calibration."
            writes: "model/rul/, config/rul/"
            status: "stage"
            docPath: "/home/zee/ITI_Files/GP/ai/AI/docs/host_pipeline/rul.md"
        }
        ListElement {
            stageName: "copy_to_rpi.py"
            role: "Copies the trained artefacts into rpi_pipeline/, refusing an inconsistent set."
            writes: "rpi_pipeline/model/, rpi_pipeline/config/"
            status: "stage"
            docPath: "/home/zee/ITI_Files/GP/ai/AI/host_pipeline/README.md"
        }
        ListElement {
            stageName: "rpi_pipeline"
            role: "C++ inference on the Raspberry Pi, with its own copy of model/ + config/."
            writes: ""
            status: "stage"
            docPath: "/home/zee/ITI_Files/GP/ai/AI/docs/rpi_pipeline.md"
        }
        ListElement {
            stageName: "gate"
            role: "Checks the model against config/pipeline.yaml's thresholds before release. PdM-Maestro's ML/Ops tab reads this stage's verdict and re-implements nothing."
            writes: "model_out/metrics.json (as of the old pipeline layout — see the tag above)"
            status: "provisional"
            docPath: "/home/zee/ITI_Files/GP/PdM_Maestro_devApp/docs/STATUS.md"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingTight

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacingTight
            implicitHeight: noticeText.implicitHeight + Theme.spacing
            color: Theme.warningSoft
            border.color: Theme.warning
            border.width: 1
            radius: Theme.radiusSmall

            Text {
                id: noticeText
                anchors.fill: parent
                anchors.margins: Theme.spacingTight
                text: qsTr("Read from the AI repo on 2026-08-20, which is being actively "
                         + "reworked by someone else as of that date. The first six stages are "
                         + "the notebook chain and are unlikely to move; the gate stage's path "
                         + "already disagrees with what PdM-Maestro's ML/Ops tab reads — see "
                         + "docs/STATUS.md. Re-check this whole view once the rework lands.")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSmall
                color: Theme.textPrimary
            }
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
                    model: stages

                    delegate: RowLayout {
                        id: rowDelegate

                        /* See the comment beside the equivalent Repeater in
                           SystemMapView.qml -- same shadowing bug, same fix:
                           declared here on the delegate's own root, never
                           read implicitly from outer scope. */
                        required property var model
                        required property int index

                        Layout.fillWidth: true
                        spacing: 0

                        Item {
                            id: rail

                            readonly property var entry: rowDelegate.model
                            readonly property bool isGate: rail.entry.status === "provisional"
                            readonly property bool isFirst: rowDelegate.index === 0
                            readonly property bool isLast: rowDelegate.index === stages.count - 1

                            Layout.preferredWidth: Theme.spacingLoose + Theme.spacing
                            Layout.fillHeight: true

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

                            /* the flow arrow -- drawn last so it sits on top
                               of the spine's lower segment, right where the
                               next stage's line picks up. */
                            Shape {
                                visible: !rail.isLast
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -3
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 10
                                height: 6

                                ShapePath {
                                    fillColor: Theme.textDisabled
                                    strokeColor: "transparent"
                                    startX: 0; startY: 0
                                    PathLine { x: 10; y: 0 }
                                    PathLine { x: 5; y: 6 }
                                    PathLine { x: 0; y: 0 }
                                }
                            }

                            /* the node: a numbered circle for a processing
                               stage, a numbered diamond for the gate --
                               a checkpoint, not a step, reads differently on
                               purpose. */
                            Rectangle {
                                id: node
                                anchors.centerIn: parent
                                width: rail.isGate ? 16 : 22
                                height: width
                                radius: rail.isGate ? Theme.radiusSmall : width / 2
                                rotation: rail.isGate ? 45 : 0
                                color: rail.isGate ? Theme.warningSoft : Theme.primarySoft
                                border.width: 2
                                border.color: rail.isGate ? Theme.warning : Theme.primary

                                Text {
                                    anchors.centerIn: parent
                                    rotation: rail.isGate ? -45 : 0
                                    text: rowDelegate.index + 1
                                    font.pixelSize: Theme.fontTiny
                                    font.weight: Font.DemiBold
                                    color: rail.isGate ? Theme.warning : Theme.primary
                                }
                            }
                        }

                        StageCard {
                            Layout.fillWidth: true
                            stageName: rowDelegate.model.stageName
                            role: rowDelegate.model.role
                            writes: rowDelegate.model.writes
                            status: rowDelegate.model.status
                            docPath: rowDelegate.model.docPath
                        }
                    }
                }
            }
        }
    }
}
