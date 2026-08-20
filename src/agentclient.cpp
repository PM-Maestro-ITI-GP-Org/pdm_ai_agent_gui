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

namespace PdM {
namespace Agent {

static constexpr auto kKeyServerUrl = "agent/serverUrl";
static constexpr auto kKeySelectedModel = "agent/selectedModel";
static constexpr auto kDefaultServerUrl = "http://127.0.0.1:8420";

static constexpr int kPollIntervalMs = 5000;
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

} // namespace Agent
} // namespace PdM
