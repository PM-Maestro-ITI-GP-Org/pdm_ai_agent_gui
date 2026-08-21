#ifndef PDM_AGENT_AGENTCLIENT_H
#define PDM_AGENT_AGENTCLIENT_H

#include <QtQml/qqmlregistration.h>
#include <QObject>
#include <QStringList>
#include <QVariantList>

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

    Q_PROPERTY(QVariantList modelCatalog READ modelCatalog NOTIFY modelCatalogChanged)

    Q_PROPERTY(bool downloadActive READ downloadActive NOTIFY downloadStateChanged)
    Q_PROPERTY(QString downloadingModelId READ downloadingModelId NOTIFY downloadStateChanged)
    Q_PROPERTY(qint64 downloadBytesDone READ downloadBytesDone NOTIFY downloadStateChanged)
    Q_PROPERTY(qint64 downloadBytesTotal READ downloadBytesTotal NOTIFY downloadStateChanged)
    Q_PROPERTY(double downloadPercent READ downloadPercent NOTIFY downloadStateChanged)
    Q_PROPERTY(bool downloadDone READ downloadDone NOTIFY downloadStateChanged)
    Q_PROPERTY(QString downloadError READ downloadError NOTIFY downloadStateChanged)

    Q_PROPERTY(bool chatBusy READ chatBusy NOTIFY chatStateChanged)
    Q_PROPERTY(QString chatAnswer READ chatAnswer NOTIFY chatStateChanged)
    Q_PROPERTY(QString chatError READ chatError NOTIFY chatStateChanged)

public:
    explicit AgentClient(QObject *parent = nullptr);

    QString serverUrl() const { return m_serverUrl; }
    bool reachable() const { return m_reachable; }
    bool backendConnected() const { return m_backendConnected; }
    QString backendName() const { return m_backendName; }
    QStringList availableModels() const { return m_availableModels; }
    QString selectedModel() const { return m_selectedModel; }
    QString statusText() const { return m_statusText; }

    QVariantList modelCatalog() const { return m_modelCatalog; }

    bool downloadActive() const { return m_downloadActive; }
    QString downloadingModelId() const { return m_downloadingModelId; }
    qint64 downloadBytesDone() const { return m_downloadBytesDone; }
    qint64 downloadBytesTotal() const { return m_downloadBytesTotal; }
    double downloadPercent() const { return m_downloadPercent; }
    bool downloadDone() const { return m_downloadDone; }
    QString downloadError() const { return m_downloadError; }

    bool chatBusy() const { return m_chatBusy; }
    QString chatAnswer() const { return m_chatAnswer; }
    QString chatError() const { return m_chatError; }

    void setServerUrl(const QString &v);
    void setSelectedModel(const QString &v);

    Q_INVOKABLE void checkConnection();
    Q_INVOKABLE void refreshCatalog();
    Q_INVOKABLE void downloadModel(const QString &id);
    Q_INVOKABLE void askQuestion(const QString &text);

signals:
    void serverUrlChanged();
    void statusChanged();
    void availableModelsChanged();
    void selectedModelChanged();
    void modelCatalogChanged();
    void downloadStateChanged();
    void chatStateChanged();

private:
    void load();
    void fetchModels();
    void setStatusText(const QString &s);
    void pollDownloadStatus();
    void resetDownloadState();

    QNetworkAccessManager *m_net = nullptr;

    QString m_serverUrl;
    QString m_selectedModel;

    bool m_reachable = false;
    bool m_backendConnected = false;
    QString m_backendName;
    QStringList m_availableModels;
    QString m_statusText = QStringLiteral("not connected");

    QTimer *m_pollTimer = nullptr;

    QVariantList m_modelCatalog;

    bool m_downloadActive = false;
    QString m_downloadingModelId;
    qint64 m_downloadBytesDone = 0;
    qint64 m_downloadBytesTotal = 0;
    double m_downloadPercent = 0.0;
    bool m_downloadDone = false;
    QString m_downloadError;

    QTimer *m_downloadPollTimer = nullptr;

    bool m_chatBusy = false;
    QString m_chatAnswer;
    QString m_chatError;
};

} // namespace Agent
} // namespace PdM

#endif // PDM_AGENT_AGENTCLIENT_H
