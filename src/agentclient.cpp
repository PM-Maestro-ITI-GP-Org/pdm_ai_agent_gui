#include "agentclient.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonValue>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QSettings>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>

namespace PdM {
namespace Agent {

static constexpr auto kKeyServerUrl = "agent/serverUrl";
static constexpr auto kKeySelectedModel = "agent/selectedModel";
static constexpr auto kKeyServerStartCommand = "agent/serverStartCommand";
static constexpr auto kDefaultServerUrl = "http://127.0.0.1:8420";

static constexpr int kPollIntervalMs = 5000;
static constexpr int kDownloadPollIntervalMs = 500;
static constexpr int kRequestTimeoutMs = 4000;
static constexpr int kChatTimeoutMs = 120000;

AgentClient::AgentClient(QObject *parent)
    : QObject(parent)
    , m_net(new QNetworkAccessManager(this))
{
    load();

    m_pollTimer = new QTimer(this);
    m_pollTimer->setInterval(kPollIntervalMs);
    connect(m_pollTimer, &QTimer::timeout, this, &AgentClient::checkConnection);
    m_pollTimer->start();

    m_downloadPollTimer = new QTimer(this);
    m_downloadPollTimer->setInterval(kDownloadPollIntervalMs);
    connect(m_downloadPollTimer, &QTimer::timeout, this, &AgentClient::pollDownloadStatus);

    checkConnection();
}

void AgentClient::load()
{
    QSettings s;
    m_serverUrl = s.value(kKeyServerUrl, QString::fromLatin1(kDefaultServerUrl)).toString();
    m_selectedModel = s.value(kKeySelectedModel).toString();
    /* No default on purpose: without setup.py (or a hand edit) there is no
       command this class could guess -- it doesn't know where the server
       checkout lives, and inventing a path would turn "not configured" into
       "launches something wrong", which is worse. */
    m_serverStartCommand = s.value(kKeyServerStartCommand).toString();
}

void AgentClient::setServerUrl(const QString &v)
{
    if (m_serverUrl == v)
        return;
    m_serverUrl = v;
    QSettings().setValue(kKeyServerUrl, m_serverUrl);
    emit serverUrlChanged();
    checkConnection();
}

void AgentClient::setSelectedModel(const QString &v)
{
    if (m_selectedModel == v)
        return;
    m_selectedModel = v;
    QSettings().setValue(kKeySelectedModel, m_selectedModel);
    emit selectedModelChanged();
}

void AgentClient::setServerStartCommand(const QString &v)
{
    if (m_serverStartCommand == v)
        return;
    m_serverStartCommand = v;
    QSettings().setValue(kKeyServerStartCommand, m_serverStartCommand);
    emit serverStartCommandChanged();
}

void AgentClient::startServer()
{
    if (m_serverStartCommand.trimmed().isEmpty()) {
        setStatusText(tr("no start command — run setup.py from the pdm_ai_server repo, or set it in Settings"));
        emit statusChanged();
        return;
    }

    /* Detached, via the user's shell: the command is a full shell line written
       by setup.py (cd + exec uvicorn ...), and the process must outlive this
       one -- the GUI closing must not take the model backend down with it.
       Failure here is almost always "shell missing", which the status line
       reports rather than pretending a start happened. */
    if (QProcess::startDetached(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), m_serverStartCommand})) {
        setStatusText(tr("starting local AI server…"));
    } else {
        setStatusText(tr("could not launch: %1").arg(m_serverStartCommand));
    }
    emit statusChanged();
    /* Reachability picks up on the next poll tick; no special-casing the
       timer for what is, at worst, five extra seconds. */
}

void AgentClient::setStatusText(const QString &s)
{
    m_statusText = s;
    /* statusChanged already covers reachable/backendConnected/backendName;
       piggybacking statusText on it keeps one signal per "the summary
       changed" rather than a signal per field. */
}

void AgentClient::checkConnection()
{
    QNetworkRequest req{ QUrl(m_serverUrl + QStringLiteral("/health")) };
    req.setTransferTimeout(kRequestTimeoutMs);

    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            m_reachable = false;
            m_backendConnected = false;
            m_backendName.clear();
            setStatusText(tr("server unreachable at %1").arg(m_serverUrl));
            emit statusChanged();
            if (!m_availableModels.isEmpty()) {
                m_availableModels.clear();
                emit availableModelsChanged();
            }
            return;
        }

        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isObject()) {
            m_reachable = false;
            m_backendConnected = false;
            m_backendName.clear();
            setStatusText(tr("server at %1 sent an unreadable reply").arg(m_serverUrl));
            emit statusChanged();
            return;
        }

        const QJsonObject obj = doc.object();
        m_reachable = true;
        m_backendConnected = obj.value(QStringLiteral("connected")).toBool();
        m_backendName = obj.value(QStringLiteral("backend")).toString();

        setStatusText(m_backendConnected
                          ? tr("connected — %1").arg(m_backendName)
                          : tr("server up, model backend unreachable"));
        emit statusChanged();

        if (m_backendConnected)
            fetchModels();
        else if (!m_availableModels.isEmpty()) {
            m_availableModels.clear();
            emit availableModelsChanged();
        }
    });
}

void AgentClient::fetchModels()
{
    QNetworkRequest req{ QUrl(m_serverUrl + QStringLiteral("/models")) };
    req.setTransferTimeout(kRequestTimeoutMs);

    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        QStringList models;
        if (reply->error() == QNetworkReply::NoError) {
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            if (doc.isObject()) {
                const QJsonArray arr = doc.object().value(QStringLiteral("models")).toArray();
                for (const QJsonValue &v : arr)
                    models << v.toString();
            }
        }

        if (models != m_availableModels) {
            m_availableModels = models;
            emit availableModelsChanged();
        }
    });
}

void AgentClient::refreshCatalog()
{
    QNetworkRequest req{ QUrl(m_serverUrl + QStringLiteral("/catalog")) };
    req.setTransferTimeout(kRequestTimeoutMs);

    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError)
            return;

        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isObject())
            return;

        QVariantList catalog;
        const QJsonArray arr = doc.object().value(QStringLiteral("models")).toArray();
        for (const QJsonValue &v : arr) {
            const QJsonObject o = v.toObject();
            QVariantMap entry;
            entry[QStringLiteral("id")] = o.value(QStringLiteral("id")).toString();
            entry[QStringLiteral("label")] = o.value(QStringLiteral("label")).toString();
            entry[QStringLiteral("repo")] = o.value(QStringLiteral("repo")).toString();
            entry[QStringLiteral("filename")] = o.value(QStringLiteral("filename")).toString();
            entry[QStringLiteral("sizeBytes")] = o.value(QStringLiteral("size_bytes")).toVariant();
            entry[QStringLiteral("installed")] = o.value(QStringLiteral("installed")).toBool();
            catalog << entry;
        }

        m_modelCatalog = catalog;
        emit modelCatalogChanged();
    });
}

void AgentClient::downloadModel(const QString &id)
{
    QNetworkRequest req{ QUrl(m_serverUrl + QStringLiteral("/download")) };
    req.setTransferTimeout(kRequestTimeoutMs);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));

    const QJsonObject body{ { QStringLiteral("id"), id } };
    QNetworkReply *reply = m_net->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, id]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError
            && reply->error() != QNetworkReply::ContentConflictError
            && reply->error() != QNetworkReply::ContentNotFoundError) {
            m_downloadError = tr("could not reach %1 to start the download").arg(m_serverUrl);
            emit downloadStateChanged();
            return;
        }

        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QJsonObject obj = doc.object();

        if (obj.value(QStringLiteral("already_installed")).toBool()) {
            refreshCatalog();
            return;
        }

        if (!obj.value(QStringLiteral("started")).toBool()) {
            m_downloadError = obj.value(QStringLiteral("error")).toString(
                tr("download could not be started"));
            emit downloadStateChanged();
            return;
        }

        resetDownloadState();
        m_downloadActive = true;
        m_downloadingModelId = id;
        emit downloadStateChanged();

        if (!m_downloadPollTimer->isActive())
            m_downloadPollTimer->start();
        pollDownloadStatus();
    });
}

void AgentClient::activateModel(const QString &id)
{
    QNetworkRequest req{ QUrl(m_serverUrl + QStringLiteral("/activate")) };
    req.setTransferTimeout(kRequestTimeoutMs);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));

    const QJsonObject body{ { QStringLiteral("id"), id } };
    QNetworkReply *reply = m_net->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        // Whatever happened -- started, already running, or the server
        // rejected it -- checkConnection's own poll picks up the real
        // backendConnected/statusText, same as "Check now" already does.
        checkConnection();
    });
}

void AgentClient::resetDownloadState()
{
    m_downloadActive = false;
    m_downloadingModelId.clear();
    m_downloadBytesDone = 0;
    m_downloadBytesTotal = 0;
    m_downloadPercent = 0.0;
    m_downloadDone = false;
    m_downloadError.clear();
}

void AgentClient::pollDownloadStatus()
{
    QNetworkRequest req{ QUrl(m_serverUrl + QStringLiteral("/download/status")) };
    req.setTransferTimeout(kRequestTimeoutMs);

    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError)
            return;

        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isObject())
            return;

        const QJsonObject obj = doc.object();
        m_downloadActive = obj.value(QStringLiteral("active")).toBool();
        m_downloadingModelId = obj.value(QStringLiteral("id")).toString();
        m_downloadBytesDone = static_cast<qint64>(obj.value(QStringLiteral("bytes_downloaded")).toDouble());
        m_downloadBytesTotal = static_cast<qint64>(obj.value(QStringLiteral("bytes_total")).toDouble());
        m_downloadPercent = obj.value(QStringLiteral("percent")).toDouble();
        m_downloadDone = obj.value(QStringLiteral("done")).toBool();
        m_downloadError = obj.value(QStringLiteral("error")).toString();
        emit downloadStateChanged();

        if (!m_downloadActive) {
            m_downloadPollTimer->stop();
            if (m_downloadDone)
                refreshCatalog();
        }
    });
}

void AgentClient::askQuestion(const QString &text, const QVariantList &history)
{
    m_chatBusy = true;
    m_chatAnswer.clear();
    m_chatError.clear();
    m_chatSources.clear();
    m_chatGrounded = false;
    m_chatCitationChecked = false;
    m_chatCitationSupported = false;
    m_chatBestSupported = 0;
    m_chatToolCalls.clear();
    emit chatStateChanged();

    QNetworkRequest req{ QUrl(m_serverUrl + QStringLiteral("/chat")) };
    req.setTransferTimeout(kChatTimeoutMs);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));

    QJsonObject body{ { QStringLiteral("message"), text } };
    /* The picker in SettingsView was inert until now: the server has always
       accepted a "model" field under Ollama and this never sent one, so every
       question silently went to whichever model /models happened to list
       first. Omitted rather than sent empty, which the server reads as "you
       choose" -- and llamacpp ignores it either way, having one model. */
    if (!m_selectedModel.isEmpty())
        body.insert(QStringLiteral("model"), m_selectedModel);
    if (!history.isEmpty()) {
        QJsonArray historyArray;
        for (const QVariant &turn : history)
            historyArray.append(QJsonObject::fromVariantMap(turn.toMap()));
        body.insert(QStringLiteral("history"), historyArray);
    }
    QNetworkReply *reply = m_net->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QJsonObject obj = doc.object();

        if (reply->error() != QNetworkReply::NoError) {
            m_chatError = obj.value(QStringLiteral("error")).toString(
                tr("could not reach %1").arg(m_serverUrl));
            m_chatBusy = false;
            emit chatStateChanged();
            return;
        }

        if (!doc.isObject() || !obj.contains(QStringLiteral("answer"))) {
            m_chatError = tr("server sent an unreadable reply");
            m_chatBusy = false;
            emit chatStateChanged();
            return;
        }

        m_chatAnswer = obj.value(QStringLiteral("answer")).toString();

        /* Sources are optional on the wire on purpose: a server still running
           the A2a build answers without them, and that has to degrade to "no
           citations shown" rather than "unreadable reply". */
        m_chatSources.clear();
        const QJsonArray sources = obj.value(QStringLiteral("sources")).toArray();
        for (const QJsonValue &value : sources) {
            const QJsonObject source = value.toObject();
            m_chatSources.append(QVariantMap{
                { QStringLiteral("n"), source.value(QStringLiteral("n")).toInt() },
                { QStringLiteral("path"), source.value(QStringLiteral("path")).toString() },
                { QStringLiteral("heading"), source.value(QStringLiteral("heading")).toString() },
                { QStringLiteral("citation"), source.value(QStringLiteral("citation")).toString() },
                { QStringLiteral("score"), source.value(QStringLiteral("score")).toDouble() },
                { QStringLiteral("cited"), source.value(QStringLiteral("cited")).toBool() },
            });
        }
        m_chatGrounded = obj.value(QStringLiteral("grounded")).toBool();

        const QJsonObject check = obj.value(QStringLiteral("citation_check")).toObject();
        m_chatCitationChecked = check.value(QStringLiteral("checked")).toBool();
        m_chatCitationSupported = check.value(QStringLiteral("supported")).toBool();
        m_chatBestSupported = check.value(QStringLiteral("best_supported")).toInt();

        /* A2b, tool half. Optional on the wire for the same reason sources
           were in A2a: an older server still answers without this field, and
           that has to degrade to "no tool was called" rather than an
           unreadable reply. */
        m_chatToolCalls.clear();
        const QJsonArray toolCalls = obj.value(QStringLiteral("tool_calls")).toArray();
        for (const QJsonValue &value : toolCalls) {
            const QJsonObject call = value.toObject();
            m_chatToolCalls.append(QVariantMap{
                { QStringLiteral("name"), call.value(QStringLiteral("name")).toString() },
                { QStringLiteral("arguments"), call.value(QStringLiteral("arguments")).toVariant() },
                { QStringLiteral("result"), call.value(QStringLiteral("result")).toVariant() },
            });
        }

        m_chatBusy = false;
        emit chatStateChanged();
    });
}

} // namespace Agent
} // namespace PdM
