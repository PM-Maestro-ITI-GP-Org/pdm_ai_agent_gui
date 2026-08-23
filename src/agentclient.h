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
    /* The command behind the "Start local AI" affordance -- normally written
       for the user by pdm_ai_server's setup.py (which knows where the venv
       landed), editable in SettingsView. Empty means there is nothing to
       launch, and the UI says so rather than showing a button that cannot
       work. */
    Q_PROPERTY(QString serverStartCommand READ serverStartCommand
                   WRITE setServerStartCommand NOTIFY serverStartCommandChanged)

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

    /* A2b: the sections the answer was retrieved from, each carrying whether
       the model actually cited it. Shown rather than hidden -- SCOPE.md §7
       makes citation a requirement, so an answer that cites nothing has to
       look different from one that does, not merely score worse somewhere. */
    Q_PROPERTY(QVariantList chatSources READ chatSources NOTIFY chatStateChanged)
    Q_PROPERTY(bool chatGrounded READ chatGrounded NOTIFY chatStateChanged)

    /* Whether the answer resembles the source it *claimed*, not merely
       whether it printed a number. The server checks this because the model
       was observed answering correctly out of one section and citing a
       different one; `chatGrounded` alone would have called that grounded.
       Three states, not two -- unchecked is not the same as failed. */
    Q_PROPERTY(bool chatCitationChecked READ chatCitationChecked NOTIFY chatStateChanged)
    Q_PROPERTY(bool chatCitationSupported READ chatCitationSupported NOTIFY chatStateChanged)
    Q_PROPERTY(int chatBestSupported READ chatBestSupported NOTIFY chatStateChanged)

    /* A2b, tool half: which tool (if any) the server called before answering,
       and what it got back -- a list of {name, arguments, result}. Empty on
       the common path; tools are additive per docs/SCOPE.md §6.3, never
       required for an answer to exist. QML acts on a "navigate_to" entry by
       publishing on MessageBus itself (see ChatView.qml) rather than this
       client reaching into the bus -- every other publish in this codebase
       already happens from QML, and this class stays what its own header
       comment above calls it: a thin HTTP client, nothing more. */
    Q_PROPERTY(QVariantList chatToolCalls READ chatToolCalls NOTIFY chatStateChanged)

public:
    explicit AgentClient(QObject *parent = nullptr);

    QString serverUrl() const { return m_serverUrl; }
    bool reachable() const { return m_reachable; }
    bool backendConnected() const { return m_backendConnected; }
    QString backendName() const { return m_backendName; }
    QStringList availableModels() const { return m_availableModels; }
    QString selectedModel() const { return m_selectedModel; }
    QString statusText() const { return m_statusText; }
    QString serverStartCommand() const { return m_serverStartCommand; }

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
    QVariantList chatSources() const { return m_chatSources; }
    bool chatGrounded() const { return m_chatGrounded; }
    bool chatCitationChecked() const { return m_chatCitationChecked; }
    bool chatCitationSupported() const { return m_chatCitationSupported; }
    int chatBestSupported() const { return m_chatBestSupported; }
    QVariantList chatToolCalls() const { return m_chatToolCalls; }

    void setServerUrl(const QString &v);
    void setSelectedModel(const QString &v);
    void setServerStartCommand(const QString &v);

    Q_INVOKABLE void checkConnection();
    /* The bootstrap half of "easy setup": the server cannot download its own
       runtime, install its own venv, or be reached at all until something
       starts it -- this is that something, run detached so it outlives the
       GUI. One-shot by design (docs/SCOPE.md §6.1: AI lives outside Qt);
       everything after uvicorn is up stays server-side. */
    Q_INVOKABLE void startServer();
    Q_INVOKABLE void refreshCatalog();
    Q_INVOKABLE void downloadModel(const QString &id);
    /* `history` is the client's own transcript, oldest first, each entry
       {role: "user"|"assistant", content: string} -- QML owns the transcript
       (ChatView.qml), this just serializes whatever it's handed. Optional:
       an empty list is a first question, same as omitting it used to be. */
    Q_INVOKABLE void askQuestion(const QString &text, const QVariantList &history = {});

signals:
    void serverUrlChanged();
    void statusChanged();
    void serverStartCommandChanged();
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
    QString m_serverStartCommand;

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
    QVariantList m_chatSources;
    bool m_chatGrounded = false;
    bool m_chatCitationChecked = false;
    bool m_chatCitationSupported = false;
    int m_chatBestSupported = 0;
    QVariantList m_chatToolCalls;
};

} // namespace Agent
} // namespace PdM

#endif // PDM_AGENT_AGENTCLIENT_H
