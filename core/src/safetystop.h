#ifndef PDM_CORE_SAFETYSTOP_H
#define PDM_CORE_SAFETYSTOP_H

#include <QObject>
#include <QQmlEngine>

namespace PdM {

/*
 * The one stop that has to be reachable from anywhere in the shell.
 *
 * This exists because merging the apps into tabs created a hazard none of them
 * had alone. esp_dac/docs/06-safety.md requires the motor rig's emergency stop
 * to be reachable at every moment -- "not buried in a menu, not disabled while
 * a modal is up". Standalone, the motor control window is always the window in
 * front of you. As a tab, switching to OTA Update hides its stop button while
 * the motor is still turning.
 *
 * So an app arms this while it is doing something that must be interruptible,
 * and the shell renders a stop strip above the tab bar for as long as it stays
 * armed -- visible from every tab. Pressing it emits stopRequested(), which the
 * app that armed it acts on.
 *
 * Deliberately a request and not a command: core has no idea what stopping
 * means for a given app. The motor tab ramps the DAC to 1.20 V over two
 * seconds; something else might abort a transfer. Core only carries the signal.
 */
class SafetyStop : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool armed READ armed NOTIFY changed)
    Q_PROPERTY(QString summary READ summary NOTIFY changed)

public:
    static SafetyStop *instance();
    static SafetyStop *create(QQmlEngine *, QJSEngine *);

    bool armed() const { return m_armed; }

    /* What is running, in the operator's words -- "Scenario A, 184 s". Shown on
       the strip, because a stop button with no subject is a button you hesitate
       over, and hesitating is the thing this is meant to prevent. */
    QString summary() const { return m_summary; }

    Q_INVOKABLE void arm(const QString &summary);
    Q_INVOKABLE void disarm();

    /* Pressed by the shell's strip, or by the app's own button. */
    Q_INVOKABLE void requestStop();

signals:
    void changed();
    void stopRequested();

private:
    explicit SafetyStop(QObject *parent = nullptr);

    bool m_armed = false;
    QString m_summary;
};

} // namespace PdM

#endif // PDM_CORE_SAFETYSTOP_H
