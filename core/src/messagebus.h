#ifndef PDM_CORE_MESSAGEBUS_H
#define PDM_CORE_MESSAGEBUS_H

#include <QObject>
#include <QVariantMap>
#include <QQmlEngine>

namespace PdM {

/*
 * The one channel the apps talk to each other on.
 *
 * The point is not convenience, it is that apps must not depend on each other.
 * Data collection finishes a recording and publishes it; ML/Ops subscribes and
 * picks it up. Neither repository names the other, so both still build and run
 * alone -- which is the property the whole submodule arrangement exists to
 * protect. A direct call from one app's library into another's would compile
 * fine inside Maestro and break the standalone build of both.
 *
 * One broadcast signal rather than a map of per-topic signals: with four tabs
 * the cost of every subscriber waking for every message is irrelevant, and the
 * simpler thing has no lifetime bookkeeping to get wrong. Use BusSubscription
 * from QML rather than filtering by hand.
 */
class MessageBus : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    /* The engine gets the same object C++ does. Without this the QML singleton
       and any C++ caller would sit on two separate buses and messages would
       vanish between them -- which presents as "the signal never arrives" with
       nothing in the logs. */
    static MessageBus *instance();
    static MessageBus *create(QQmlEngine *, QJSEngine *);

    /* Topics are plain strings, dot-separated by convention:
       "recording.finished", "ota.update.available", "model.trained". */
    Q_INVOKABLE void publish(const QString &topic, const QVariantMap &payload = {});

signals:
    void message(const QString &topic, const QVariantMap &payload);

private:
    explicit MessageBus(QObject *parent = nullptr);
};

/*
 * Declarative subscription, so QML says what it wants instead of filtering:
 *
 *     BusSubscription {
 *         topic: "recording.finished"
 *         onReceived: (payload) => model.reload(payload.path)
 *     }
 */
class BusSubscription : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString topic READ topic WRITE setTopic NOTIFY topicChanged)

public:
    explicit BusSubscription(QObject *parent = nullptr);

    QString topic() const { return m_topic; }
    void setTopic(const QString &topic);

signals:
    void topicChanged();
    void received(const QVariantMap &payload);

private:
    QString m_topic;
};

} // namespace PdM

#endif // PDM_CORE_MESSAGEBUS_H
