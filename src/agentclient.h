#ifndef PDM_AGENT_AGENTCLIENT_H
#define PDM_AGENT_AGENTCLIENT_H

#include <QtQml/qqmlregistration.h>
#include <QObject>
#include <QStringList>

class QNetworkAccessManager;
class QNetworkReply;
class QTimer;

namespace PdM {
namespace Agent {

/*
 * The Qt-side half of the A2a HTTP contract in docs/SCOPE.md §6.1: a thin
 * client for the local Python server, reached over a configurable URL so
 * "this laptop" and "the other laptop on the bench" are the same code path
 * (§3.3, §6.4).
 *
 * Two distinct "not connected" states, not one: `reachable` is whether the
 * server itself answers at all, `backendConnected` is whether *its* model
 * backend (llama.cpp/Ollama) is up. The server not existing yet is the
 * common case this is built for, not an edge case.
 */
class AgentClient : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString serverUrl READ serverUrl WRITE setServerUrl NOTIFY serverUrlChanged)
    Q_PROPERTY(bool reachable READ reachable NOTIFY statusChanged)
    Q_PROPERTY(bool backendConnected READ backendConnected NOTIFY statusChanged)
    Q_PROPERTY(QString backendName READ backendName NOTIFY statusChanged)
    Q_PROPERTY(QStringList availableModels READ availableModels NOTIFY availableModelsChanged)
    Q_PROPERTY(QString selectedModel READ selectedModel WRITE setSelectedModel
                   NOTIFY selectedModelChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusChanged)

public:
    explicit AgentClient(QObject *parent = nullptr);

    QString serverUrl() const { return m_serverUrl; }
    bool reachable() const { return m_reachable; }
    bool backendConnected() const { return m_backendConnected; }
    QString backendName() const { return m_backendName; }
    QStringList availableModels() const { return m_availableModels; }
    QString selectedModel() const { return m_selectedModel; }
    QString statusText() const { return m_statusText; }

    void setServerUrl(const QString &v);
    void setSelectedModel(const QString &v);

    Q_INVOKABLE void checkConnection();

signals:
    void serverUrlChanged();
    void statusChanged();
    void availableModelsChanged();
    void selectedModelChanged();

private:
    void load();
    void fetchModels();
    void setStatusText(const QString &s);

    QNetworkAccessManager *m_net = nullptr;

    QString m_serverUrl;
    QString m_selectedModel;

    bool m_reachable = false;
    bool m_backendConnected = false;
    QString m_backendName;
    QStringList m_availableModels;
    QString m_statusText = QStringLiteral("not connected");

    QTimer *m_pollTimer = nullptr;
};

} // namespace Agent
} // namespace PdM

#endif // PDM_AGENT_AGENTCLIENT_H
