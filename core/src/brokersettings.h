#ifndef PDM_CORE_BROKERSETTINGS_H
#define PDM_CORE_BROKERSETTINGS_H

#include <QObject>
#include <QQmlEngine>

namespace PdM {

/*
 * Where the MQTT broker is, said once.
 *
 * This is deliberately NOT a shared MQTT client. The two apps ship genuinely
 * different clients -- 690 lines against 1421, different topic trees
 * (guest/rpi5guest1/* against hms/*), different QoS, one threaded and one not --
 * and merging them would be a rewrite of two working implementations for no
 * gain the shell can see. They stay as they are.
 *
 * What they should not each own is the address. Both currently hardcode
 * tcp://139.185.38.211:1883 as a #define in their own .cpp, so pointing the
 * system at a different broker means editing two files in two repositories and
 * remembering that a third and fourth app will need the same edit. One setting,
 * persisted, changeable at runtime.
 *
 * NOTE for the ports: the client-id collision this class was originally going
 * to arbitrate does not exist. Both apps already suffix an epoch timestamp
 * (motor_gui_<ms>, ota_gui_<ms>), so two connections from one process are
 * distinct at the broker. clientId() below exists to keep that true as apps
 * three and four arrive, not to fix something broken.
 */
class BrokerSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString url READ url WRITE setUrl NOTIFY urlChanged)

public:
    static BrokerSettings *instance();
    static BrokerSettings *create(QQmlEngine *, QJSEngine *);

    /* "tcp://host:port", the form Paho's MQTTClient_create() wants. */
    QString url() const { return m_url; }
    void setUrl(const QString &url);

    /*
     * A client id that is unique per app and per run: "pdm_<appId>_<pid>_<ms>".
     *
     * The pid matters more than it looks. Two *processes* started in the same
     * millisecond -- Maestro and a developer running motor_gui standalone
     * against the same broker, which happens constantly during the ports --
     * would otherwise pick the same id, and MQTT resolves that by disconnecting
     * the older session. The result is two apps taking turns kicking each other
     * off, presenting as an unstable broker rather than as an id clash.
     */
    Q_INVOKABLE QString clientId(const QString &appId) const;

signals:
    void urlChanged();

private:
    explicit BrokerSettings(QObject *parent = nullptr);

    QString m_url;
};

} // namespace PdM

#endif // PDM_CORE_BROKERSETTINGS_H
