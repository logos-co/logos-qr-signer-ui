#include "qr_signer_ui_backend.h"

#include <QJsonArray>
#include <QJsonDocument>

// The generated umbrella carrying `struct LogosModules`.
#include "logos_sdk.h"

namespace {

QJsonObject parseObject(const QString &reply)
{
    return QJsonDocument::fromJson(reply.toUtf8()).object();
}

QString compact(const QJsonValue &v)
{
    if (v.isArray())
        return QString::fromUtf8(QJsonDocument(v.toArray()).toJson(QJsonDocument::Compact));
    if (v.isObject())
        return QString::fromUtf8(QJsonDocument(v.toObject()).toJson(QJsonDocument::Compact));
    return {};
}

} // namespace

bool QrSignerUiBackend::ok(const QJsonObject &reply, const QString &context)
{
    if (reply.value(QStringLiteral("ok")).toBool())
        return true;
    QString e = reply.value(QStringLiteral("error")).toString();
    if (e.isEmpty())
        e = QStringLiteral("the QR signer didn't answer");
    setLastError(QStringLiteral("%1: %2").arg(context, e));
    return false;
}

void QrSignerUiBackend::onContextReady()
{
    // The accounts changed: read them again, off the IPC stack.
    modules().qr_signer_module.onSigner_accounts_changed([this](auto) {
        QTimer::singleShot(0, this, [this] { refresh(); });
    });
    m_poll.setInterval(500);
    QObject::connect(&m_poll, &QTimer::timeout, this, [this] { poll(); });
    const QJsonObject profiles = parseObject(modules().qr_signer_module.profiles());
    if (ok(profiles, QStringLiteral("wallets")))
        setProfilesJson(compact(profiles.value(QStringLiteral("profiles"))));
    refresh();
}

void QrSignerUiBackend::refresh()
{
    const QJsonObject accounts = parseObject(modules().qr_signer_module.signer_accounts());
    const bool read = ok(accounts, QStringLiteral("accounts"));
    setAccountsJson(read ? compact(accounts.value(QStringLiteral("accounts"))) : QStringLiteral("[]"));
    setStatusText(read ? QStringLiteral("Ready") : QStringLiteral("The QR signer isn't answering"));
}

bool QrSignerUiBackend::scan(QString familiesJson, QString profile, QString label)
{
    setLastError(QString());
    QJsonObject p;
    p.insert(QStringLiteral("families"), QJsonDocument::fromJson(familiesJson.toUtf8()).array());
    if (!profile.isEmpty())
        p.insert(QStringLiteral("profile"), profile);
    if (!label.trimmed().isEmpty())
        p.insert(QStringLiteral("label"), label.trimmed());
    const QJsonObject reply = parseObject(modules().qr_signer_module.scan_accounts(
        QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact))));
    if (!ok(reply, QStringLiteral("scan")))
        return false;
    m_job = reply.value(QStringLiteral("job")).toString();
    setScanJson(QStringLiteral("{\"state\":\"scanning\"}"));
    m_poll.start();
    return true;
}

void QrSignerUiBackend::poll()
{
    if (m_job.isEmpty()) {
        m_poll.stop();
        return;
    }
    QJsonObject reply = parseObject(modules().qr_signer_module.add_status(m_job));
    if (!ok(reply, QStringLiteral("scan"))) {
        m_poll.stop();
        m_job.clear();
        setScanJson(QStringLiteral("{}"));
        return;
    }
    const QString state = reply.value(QStringLiteral("state")).toString();
    reply.remove(QStringLiteral("ok"));
    reply.remove(QStringLiteral("job"));
    setScanJson(compact(reply));
    if (state == QLatin1String("done") || state == QLatin1String("failed")) {
        m_poll.stop();
        m_job.clear();
        refresh();
    }
}

bool QrSignerUiBackend::removeAccount(QString id)
{
    setLastError(QString());
    const bool removed = ok(parseObject(modules().qr_signer_module.remove_account(id)),
                            QStringLiteral("remove"));
    refresh();
    return removed;
}
