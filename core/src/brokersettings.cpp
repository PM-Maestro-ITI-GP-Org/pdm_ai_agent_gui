#include "brokersettings.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QSettings>

namespace PdM {

/* The address both apps hardcode today. Kept as the default so nothing changes
   behaviour on first run; the setting only matters once someone points the
   system somewhere else. */
static constexpr auto kDefaultBrokerUrl = "tcp://139.185.38.211:1883";
static constexpr auto kSettingsKey = "mqtt/brokerUrl";

BrokerSettings::BrokerSettings(QObject *parent)
    : QObject(parent)
{
    QSettings settings;
    m_url = settings.value(kSettingsKey, QString::fromLatin1(kDefaultBrokerUrl)).toString();
}

BrokerSettings *BrokerSettings::instance()
{
    static BrokerSettings settings;
    return &settings;
}

BrokerSettings *BrokerSettings::create(QQmlEngine *, QJSEngine *)
{
    BrokerSettings *settings = instance();
    QJSEngine::setObjectOwnership(settings, QJSEngine::CppOwnership);
    return settings;
}

void BrokerSettings::setUrl(const QString &url)
{
    if (m_url == url)
        return;

    m_url = url;

    QSettings settings;
    settings.setValue(kSettingsKey, m_url);

    emit urlChanged();
}

QString BrokerSettings::clientId(const QString &appId) const
{
    return QStringLiteral("pdm_%1_%2_%3")
        .arg(appId)
        .arg(QCoreApplication::applicationPid())
        .arg(QDateTime::currentMSecsSinceEpoch());
}

} // namespace PdM
