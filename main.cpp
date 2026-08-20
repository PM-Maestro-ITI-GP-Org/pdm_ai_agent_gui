#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QtQml/qqmlextensionplugin.h>

/*
 * The standalone entry point, and only that. Maestro does not compile this
 * file -- see PROJECT_IS_TOP_LEVEL in CMakeLists.txt -- so nothing here may
 * be load-bearing for the app itself.
 */

/* Static QML modules need an explicit import from the executable that links
   them, or the types resolve at build time and are missing at run time. */
Q_IMPORT_QML_PLUGIN(PdM_CorePlugin)
Q_IMPORT_QML_PLUGIN(PdM_AgentPlugin)

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    /* Shared with Maestro on purpose, same reasoning as pdm_mlops_gui. */
    app.setOrganizationName("PM-Maestro-ITI-GP-Org");
    app.setApplicationName("PdM AI Agent");

    QQuickStyle::setStyle("Material");

    QQmlApplicationEngine engine;

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() {
                         qCritical("[agent] FATAL: QML object creation failed");
                         QCoreApplication::exit(1);
                     }, Qt::QueuedConnection);

    engine.loadFromModule("AgentGuiApp", "Main");

    return app.exec();
}
