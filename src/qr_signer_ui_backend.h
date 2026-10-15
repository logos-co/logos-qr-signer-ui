#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QString>
#include <QTimer>

#include "rep_qr_signer_ui_source.h"
#include "logos_ui_plugin_context.h"

// The QR signer's app backend: every call to qr_signer_module is made here, over the generated
// typed client. A scan waits for the person to hold up their wallet's code, so it is polled.
class QrSignerUiBackend : public QrSignerUiSimpleSource,
                          public LogosUiPluginContext
{
public:
    void refresh() override;
    bool scan(QString familiesJson, QString profile, QString label) override;
    bool removeAccount(QString id) override;
    bool renameAccount(QString id, QString label) override;
    bool forgetWallet(QString fingerprint) override;

protected:
    void onContextReady() override;

private:
    /// Surface the module's refusal and report whether the call succeeded.
    bool ok(const QJsonObject &reply, const QString &context);
    void poll();

    QString m_job;
    QTimer m_poll;
    // The accounts as last read, for forgetting a wallet's.
    QJsonArray m_accounts;
};
