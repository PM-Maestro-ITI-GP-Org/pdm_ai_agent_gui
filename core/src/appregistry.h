#ifndef PDM_CORE_APPREGISTRY_H
#define PDM_CORE_APPREGISTRY_H

#include <QAbstractListModel>
#include <QQmlEngine>
#include <QUrl>

namespace PdM {

/*
 * What tabs exist, and which of them have an app behind them yet.
 *
 * The shell's tab bar and its page stack both bind to this model, so the list
 * of apps is stated once instead of being repeated in two Repeaters that can
 * disagree. It replaces the hard-coded array that Main.qml carried in Phase 0.
 *
 * An entry with an empty pageUrl gets a placeholder tab. That is what makes the
 * partially-integrated state a first-class thing the shell can render rather
 * than a build error: three apps ported and one not is a normal state for this
 * project for as long as the migration runs.
 */
class AppRegistry : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        GlyphRole,
        ModuleUriRole,
        RepoRole,
        StatusRole,
        PageUrlRole,
        AvailableRole,
    };
    Q_ENUM(Roles)

    static AppRegistry *instance();
    static AppRegistry *create(QQmlEngine *, QJSEngine *);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    /* Declares a tab. Keys mirror the role names: id, title, glyph, moduleUri,
       repo, status, pageUrl. Tab order is registration order. */
    Q_INVOKABLE void registerApp(const QVariantMap &app);

    /*
     * An app announces its page here once it has one, which is the single line
     * that turns a placeholder into a real tab:
     *
     *     AppRegistry::instance()->setPage(
     *         "data_collection",
     *         QUrl("qrc:/qt/qml/PdM/DataCollection/DataCollectionPage.qml"));
     *
     * A URL rather than a QQmlComponent, so registration does not need the QML
     * engine to exist yet and can run from a library's initialisation.
     * Returns false for an unknown id.
     */
    Q_INVOKABLE bool setPage(const QString &id, const QUrl &pageUrl);

    Q_INVOKABLE int indexOf(const QString &id) const;

private:
    explicit AppRegistry(QObject *parent = nullptr);

    struct Entry {
        QString id;
        QString title;
        QString glyph;
        QString moduleUri;
        QString repo;
        QString status;
        QUrl pageUrl;
    };

    QList<Entry> m_apps;
};

} // namespace PdM

#endif // PDM_CORE_APPREGISTRY_H
