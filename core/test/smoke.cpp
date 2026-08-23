/*
 * Enough of a test to prove core is wired up, and to give the standalone build
 * something to actually run.
 *
 * The contract asks every repo to keep a CI job that builds it the way its own
 * developer would; a library with nothing to execute makes that job vacuous, so
 * this is what CI runs.
 */
#include <QCoreApplication>
#include <QDebug>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QtQml/qqmlextensionplugin.h>

#include "appregistry.h"
#include "brokersettings.h"
#include "messagebus.h"

/* The QML half of this module is a static plugin like any other, so the test
   has to import it explicitly or PdM.Core resolves to nothing. */
Q_IMPORT_QML_PLUGIN(PdM_CorePlugin)

static int failures = 0;

static void check(bool condition, const char *what)
{
    if (condition) {
        qInfo() << "  ok  " << what;
    } else {
        qWarning() << "  FAIL" << what;
        ++failures;
    }
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    app.setOrganizationName("PM-Maestro-ITI-GP-Org");
    app.setApplicationName("pdm_core_smoke");

    qInfo() << "message bus";
    {
        QString seenTopic;
        QVariantMap seenPayload;

        /*
         * `scope` and not `&app` as the connection's context object, and
         * declared after what the lambda captures.
         *
         * The bus outlives every scope in this file, so a connection made
         * against the application object stays live for the whole run while the
         * lambda holds references to these two locals. The first version did
         * exactly that, and it was fine right up until a later test published a
         * second message -- at which point the handler wrote into a stack frame
         * that had been gone for twenty lines. Declared last, `scope` is
         * destroyed first, taking the connection with it while the captures are
         * still alive.
         */
        QObject scope;
        QObject::connect(PdM::MessageBus::instance(), &PdM::MessageBus::message,
                         &scope, [&](const QString &topic, const QVariantMap &payload) {
                             seenTopic = topic;
                             seenPayload = payload;
                         });

        PdM::MessageBus::instance()->publish("recording.finished",
                                             { { "path", "/tmp/run-1.csv" } });

        check(seenTopic == "recording.finished", "subscriber sees the topic");
        check(seenPayload.value("path").toString() == "/tmp/run-1.csv",
              "subscriber sees the payload");
    }

    qInfo() << "app registry";
    {
        auto *registry = PdM::AppRegistry::instance();
        registry->registerApp({ { "id", "data_collection" }, { "title", "Data Collection" } });
        registry->registerApp({ { "id", "ota" }, { "title", "OTA Update" } });

        check(registry->rowCount() == 2, "two apps registered");
        check(registry->indexOf("ota") == 1, "registration order is tab order");

        /* A duplicate id would give the shell two tabs claiming to be the same
           app, with the second silently shadowing the first. */
        registry->registerApp({ { "id", "ota" }, { "title", "Duplicate" } });
        check(registry->rowCount() == 2, "duplicate id is rejected");

        const QModelIndex ota = registry->index(1);
        check(!registry->data(ota, PdM::AppRegistry::AvailableRole).toBool(),
              "an app with no page is not available");

        check(registry->setPage("ota", QUrl("qrc:/qt/qml/PdM/Ota/OtaPage.qml")),
              "setPage accepts a known id");
        check(registry->data(ota, PdM::AppRegistry::AvailableRole).toBool(),
              "an app with a page is available");
        check(!registry->setPage("nope", QUrl("qrc:/x.qml")),
              "setPage rejects an unknown id");
    }

    qInfo() << "bus subscription, from QML";
    {
        /*
         * The mechanism the motor control and data collection tabs meet on:
         * one publishes recording.start, the other subscribes by topic and
         * never names the app that sent it. Worth testing here rather than in
         * either app, because it is the only thing that makes those two
         * buildable on their own.
         */
        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData(R"(
            import QtQml
            import PdM.Core
            QtObject {
                property int hits: 0
                property string lastPath: ""
                property BusSubscription sub: BusSubscription {
                    topic: "recording.start"
                    onReceived: (payload) => { hits++; lastPath = payload.name }
                }
            }
        )", QUrl("qrc:/smoke.qml"));

        QScopedPointer<QObject> obj(component.create());
        check(!obj.isNull(), "QML object with a BusSubscription is created");
        if (obj) {
            PdM::MessageBus::instance()->publish("recording.start", { { "name", "run-7" } });
            PdM::MessageBus::instance()->publish("recording.stop", { { "name", "nope" } });
            PdM::MessageBus::instance()->publish("something.else", {});

            check(obj->property("hits").toInt() == 1,
                  "subscriber fires once, only for its own topic");
            check(obj->property("lastPath").toString() == "run-7",
                  "payload survives the trip through QML");
        } else {
            qWarning() << component.errorString();
        }
    }

    qInfo() << "broker settings";
    {
        auto *broker = PdM::BrokerSettings::instance();
        check(broker->url().startsWith("tcp://"), "broker url has a default");

        /* Two apps in one process must not present the same id to the broker;
           MQTT resolves a clash by disconnecting the older session. */
        check(broker->clientId("data_collection") != broker->clientId("ota"),
              "client ids differ between apps");
    }

    if (failures > 0) {
        qWarning() << failures << "check(s) failed";
        return 1;
    }
    qInfo() << "all checks passed";
    return 0;
}
