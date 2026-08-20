#include "agentclient.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonValue>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSettings>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>

namespace PdM {
namespace Agent {

static constexpr auto kKeyServerUrl = "agent/serverUrl";
static constexpr auto kKeySelectedModel = "agent/selectedModel";
static constexpr auto kDefaultServerUrl = "http://127.0.0.1:8420";

static constexpr int kPollIntervalMs = 5000;
static constexpr int kDownloadPollIntervalMs = 500;
static constexpr int kRequestTimeoutMs = 4000;

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

} // namespace Agent
} // namespace PdM
