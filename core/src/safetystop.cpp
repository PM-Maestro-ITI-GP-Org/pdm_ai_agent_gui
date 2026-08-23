#include "safetystop.h"

#include <QLoggingCategory>

Q_LOGGING_CATEGORY(lcSafety, "pdm.core.safety")

namespace PdM {

SafetyStop::SafetyStop(QObject *parent)
    : QObject(parent)
{
}

SafetyStop *SafetyStop::instance()
{
    static SafetyStop stop;
    return &stop;
}

SafetyStop *SafetyStop::create(QQmlEngine *, QJSEngine *)
{
    SafetyStop *s = instance();
    QJSEngine::setObjectOwnership(s, QJSEngine::CppOwnership);
    return s;
}

void SafetyStop::arm(const QString &summary)
{
    if (m_armed && m_summary == summary)
        return;
    m_armed = true;
    m_summary = summary;
    qCDebug(lcSafety) << "armed:" << summary;
    emit changed();
}

void SafetyStop::disarm()
{
    if (!m_armed)
        return;
    m_armed = false;
    m_summary.clear();
    qCDebug(lcSafety) << "disarmed";
    emit changed();
}

void SafetyStop::requestStop()
{
    /* Emitted even when not armed. A stop pressed against nothing is harmless;
       a stop swallowed because core disagreed about whether anything was
       running is not. */
    qCWarning(lcSafety) << "stop requested";
    emit stopRequested();
}

} // namespace PdM
