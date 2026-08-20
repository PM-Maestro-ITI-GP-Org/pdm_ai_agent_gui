import QtQuick
import QtQuick.Controls
import PdM.Core
import PdM.Agent

/*
 * The standalone window, and nothing else.
 *
 * Not used when Maestro pulls the repository in -- the shell owns the only
 * ApplicationWindow in the merged process, and AgentPage goes straight into
 * a tab.
 */
ApplicationWindow {
    id: appWindow

    visible: true
    width: 1280
    height: 860
    minimumWidth: 900
    minimumHeight: 640
    title: qsTr("PdM AI Agent")
    color: Theme.background

    AgentPage {
        anchors.fill: parent
    }
}
