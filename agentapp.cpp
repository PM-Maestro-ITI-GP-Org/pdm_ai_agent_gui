#include "agentapp.h"

#include <QUrl>

#include "appregistry.h"

namespace PdM {
namespace Agent {

void registerWithShell()
{
    AppRegistry::instance()->setPage(
        QStringLiteral("agent"),
        QUrl(QStringLiteral("qrc:/qt/qml/PdM/Agent/AgentPage.qml")));
}

} // namespace Agent
} // namespace PdM
