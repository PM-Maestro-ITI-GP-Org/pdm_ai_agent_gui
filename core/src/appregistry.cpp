#include "appregistry.h"

#include <QLoggingCategory>

Q_LOGGING_CATEGORY(lcRegistry, "pdm.core.registry")

namespace PdM {

AppRegistry::AppRegistry(QObject *parent)
    : QAbstractListModel(parent)
{
}

AppRegistry *AppRegistry::instance()
{
    static AppRegistry registry;
    return &registry;
}

AppRegistry *AppRegistry::create(QQmlEngine *, QJSEngine *)
{
    AppRegistry *registry = instance();
    QJSEngine::setObjectOwnership(registry, QJSEngine::CppOwnership);
    return registry;
}

int AppRegistry::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_apps.size());
}

QVariant AppRegistry::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_apps.size())
        return {};

    const Entry &app = m_apps.at(index.row());
    switch (role) {
    case IdRole:        return app.id;
    case TitleRole:     return app.title;
    case GlyphRole:     return app.glyph;
    case ModuleUriRole: return app.moduleUri;
    case RepoRole:      return app.repo;
    case StatusRole:    return app.status;
    case PageUrlRole:   return app.pageUrl;
    case AvailableRole: return !app.pageUrl.isEmpty();
    default:            return {};
    }
}

QHash<int, QByteArray> AppRegistry::roleNames() const
{
    return {
        { IdRole,        "appId"     },
        { TitleRole,     "title"     },
        { GlyphRole,     "glyph"     },
        { ModuleUriRole, "moduleUri" },
        { RepoRole,      "repo"      },
        { StatusRole,    "status"    },
        { PageUrlRole,   "pageUrl"   },
        { AvailableRole, "available" },
    };
}

void AppRegistry::registerApp(const QVariantMap &app)
{
    const QString id = app.value("id").toString();
    if (id.isEmpty()) {
        qCWarning(lcRegistry) << "refusing to register an app with no id";
        return;
    }
    if (indexOf(id) >= 0) {
        qCWarning(lcRegistry) << "app already registered, ignoring:" << id;
        return;
    }

    Entry entry;
    entry.id        = id;
    entry.title     = app.value("title").toString();
    entry.glyph     = app.value("glyph").toString();
    entry.moduleUri = app.value("moduleUri").toString();
    entry.repo      = app.value("repo").toString();
    entry.status    = app.value("status").toString();
    entry.pageUrl   = app.value("pageUrl").toUrl();

    beginInsertRows({}, int(m_apps.size()), int(m_apps.size()));
    m_apps.append(entry);
    endInsertRows();
}

bool AppRegistry::setPage(const QString &id, const QUrl &pageUrl)
{
    const int row = indexOf(id);
    if (row < 0) {
        qCWarning(lcRegistry) << "setPage for unknown app:" << id;
        return false;
    }

    m_apps[row].pageUrl = pageUrl;
    const QModelIndex idx = index(row);
    emit dataChanged(idx, idx, { PageUrlRole, AvailableRole });
    qCDebug(lcRegistry) << "app" << id << "provided a page:" << pageUrl;
    return true;
}

int AppRegistry::indexOf(const QString &id) const
{
    for (int i = 0; i < m_apps.size(); ++i) {
        if (m_apps.at(i).id == id)
            return i;
    }
    return -1;
}

} // namespace PdM
