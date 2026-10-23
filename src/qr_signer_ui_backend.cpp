#include "qr_signer_ui_backend.h"

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

QString failed(const QString &error)
{
    QJsonObject o;
    o.insert(QStringLiteral("state"), QStringLiteral("failed"));
    o.insert(QStringLiteral("error"), error);
    return compact(o);
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
    // Often enough for "a code is in view" to follow the wallet as it moves.
    m_poll.setInterval(250);
    QObject::connect(&m_poll, &QTimer::timeout, this, [this] { poll(); });
    const QJsonObject profiles = parseObject(modules().qr_signer_module.profiles());
    if (ok(profiles, QStringLiteral("wallets")))
        setProfilesJson(compact(profiles.value(QStringLiteral("profiles"))));
    refresh();
}

void QrSignerUiBackend::refresh()
{
    const QJsonObject accounts = parseObject(modules().qr_signer_module.signer_accounts());
    const QJsonObject known = parseObject(modules().qr_signer_module.wallets());
    if (!ok(accounts, QStringLiteral("accounts")) || !ok(known, QStringLiteral("wallets"))) {
        setStatusText(QStringLiteral("The QR signer isn't answering"));
        return;
    }
    m_accounts = accounts.value(QStringLiteral("accounts")).toArray();
    // One entry a master fingerprint, in the order the signer lists them, its accounts inside.
    QJsonArray wallets;
    auto at = [&wallets](const QString &fingerprint) {
        for (qsizetype i = 0; i < wallets.size(); ++i)
            if (wallets.at(i).toObject().value(QStringLiteral("fingerprint")).toString() == fingerprint)
                return i;
        return qsizetype(-1);
    };
    for (const QJsonValue &w : known.value(QStringLiteral("wallets")).toArray()) {
        QJsonObject o = w.toObject();
        o.insert(QStringLiteral("accounts"), QJsonArray());
        wallets.append(o);
    }
    for (const QJsonValue &a : m_accounts) {
        const QString fingerprint = a.toObject().value(QStringLiteral("fingerprint")).toString();
        qsizetype i = at(fingerprint);
        if (i < 0) {
            QJsonObject o;
            o.insert(QStringLiteral("fingerprint"), fingerprint);
            o.insert(QStringLiteral("accounts"), QJsonArray());
            wallets.append(o);
            i = wallets.size() - 1;
        }
        QJsonObject o = wallets.at(i).toObject();
        QJsonArray list = o.value(QStringLiteral("accounts")).toArray();
        list.append(a);
        o.insert(QStringLiteral("accounts"), list);
        wallets.replace(i, o);
    }
    setWalletsJson(compact(wallets));
    setStatusText(QStringLiteral("Ready"));
}

bool QrSignerUiBackend::scan(QString familiesJson, QString profile, QString labelsJson)
{
    setLastError(QString());
    if (!m_job.isEmpty()) {
        setLastError(QStringLiteral("A wallet's code is already being read."));
        return false;
    }
    QJsonObject p;
    p.insert(QStringLiteral("families"), QJsonDocument::fromJson(familiesJson.toUtf8()).array());
    if (!profile.isEmpty())
        p.insert(QStringLiteral("profile"), profile);
    // A name per account, by family; one left empty has none.
    QJsonObject labels;
    const QJsonObject asked = QJsonDocument::fromJson(labelsJson.toUtf8()).object();
    for (auto it = asked.begin(); it != asked.end(); ++it) {
        const QString name = it.value().toString().trimmed();
        if (!name.isEmpty())
            labels.insert(it.key(), name);
    }
    if (!labels.isEmpty())
        p.insert(QStringLiteral("labels"), labels);
    // Claimed before the scan starts, so the scanner reads it here instead of in its window. With
    // no scanner, or one that won't have this app draw, the answer is no handle: the window, as before.
    const QString h = modules().qr_scanner_module.presenter_attach();
    m_present = h.startsWith(QStringLiteral("prs_")) ? h : QString();
    const QJsonObject reply = parseObject(modules().qr_signer_module.scan_accounts(
        QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact))));
    if (!ok(reply, QStringLiteral("scan"))) {
        letScannerGo();
        setScanJson(failed(lastError()));
        return false;
    }
    m_job = reply.value(QStringLiteral("job")).toString();
    setScanJson(QStringLiteral("{\"state\":\"scanning\"}"));
    m_poll.start();
    return true;
}

bool QrSignerUiBackend::cancelScan()
{
    setLastError(QString());
    if (m_job.isEmpty())
        return false;
    // The next poll reads the outcome: cancelled, or done if the code was read meanwhile.
    const QJsonObject reply = parseObject(modules().qr_signer_module.cancel_scan(m_job));
    return ok(reply, QStringLiteral("stop")) && reply.value(QStringLiteral("cancelled")).toBool();
}

void QrSignerUiBackend::poll()
{
    if (m_job.isEmpty()) {
        m_poll.stop();
        return;
    }
    QJsonObject reply = parseObject(modules().qr_signer_module.add_status(m_job));
    if (!ok(reply, QStringLiteral("scan"))) {
        // Say so where the scan is shown, rather than leave it waiting.
        m_poll.stop();
        m_job.clear();
        letScannerGo();
        setScanJson(failed(lastError()));
        return;
    }
    const QString state = reply.value(QStringLiteral("state")).toString();
    reply.remove(QStringLiteral("ok"));
    reply.remove(QStringLiteral("job"));
    setScanJson(compact(reply));
    if (state != QLatin1String("scanning")) {
        m_poll.stop();
        m_job.clear();
        letScannerGo();
        refresh();
        return;
    }
    if (!m_present.isEmpty()) {
        // How the camera reads the code: whether one is in view, and the parts read. No picture.
        QJsonObject v = parseObject(modules().qr_scanner_module.presenter_view(m_present, QString()));
        if (v.value(QStringLiteral("ok")).toBool()) {
            v.remove(QStringLiteral("ok"));
            setScanViewJson(compact(v));
        }
    }
}

void QrSignerUiBackend::letScannerGo()
{
    setScanViewJson(QStringLiteral("{}"));
    if (m_present.isEmpty())
        return;
    modules().qr_scanner_module.presenter_detach(m_present);
    m_present.clear();
}

bool QrSignerUiBackend::removeAccount(QString id)
{
    setLastError(QString());
    const bool removed = ok(parseObject(modules().qr_signer_module.remove_account(id)),
                            QStringLiteral("remove"));
    refresh();
    return removed;
}

bool QrSignerUiBackend::renameAccount(QString id, QString label)
{
    setLastError(QString());
    const bool renamed = ok(parseObject(modules().qr_signer_module.rename_account(id, label)),
                            QStringLiteral("rename"));
    refresh();
    return renamed;
}

bool QrSignerUiBackend::forgetWallet(QString fingerprint)
{
    setLastError(QString());
    bool all = true;
    for (const QJsonValue &a : m_accounts) {
        const QJsonObject o = a.toObject();
        if (o.value(QStringLiteral("fingerprint")).toString() != fingerprint)
            continue;
        all = ok(parseObject(modules().qr_signer_module.remove_account(
                     o.value(QStringLiteral("id")).toString())),
                 QStringLiteral("forget"))
              && all;
    }
    refresh();
    return all;
}
