#include "messagebus.h"

#include <QLoggingCategory>

Q_LOGGING_CATEGORY(lcBus, "pdm.core.bus")

namespace PdM {

MessageBus::MessageBus(QObject *parent)
    : QObject(parent)
{
}

MessageBus *MessageBus::instance()
{
    /* Function-local static: constructed on first use, after QCoreApplication
       exists. A file-scope static would run before main() and the ordering
       against other translation units is not defined. */
    static MessageBus bus;
    return &bus;
}

MessageBus *MessageBus::create(QQmlEngine *, QJSEngine *engine)
{
    MessageBus *bus = instance();
    /* The engine would otherwise take ownership of a singleton it did not
       allocate and destroy it at teardown, leaving every C++ holder with a
       dangling pointer. */
    QJSEngine::setObjectOwnership(bus, QJSEngine::CppOwnership);
    Q_UNUSED(engine)
    return bus;
}

void MessageBus::publish(const QString &topic, const QVariantMap &payload)
{
    qCDebug(lcBus) << "publish" << topic << payload.keys();
    emit message(topic, payload);
}

BusSubscription::BusSubscription(QObject *parent)
    : QObject(parent)
{
    connect(MessageBus::instance(), &MessageBus::message,
            this, [this](const QString &topic, const QVariantMap &payload) {
                if (!m_topic.isEmpty() && topic == m_topic)
                    emit received(payload);
            });
}

void BusSubscription::setTopic(const QString &topic)
{
    if (m_topic == topic)
        return;
    m_topic = topic;
    emit topicChanged();
}

} // namespace PdM
